terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.0"
    }
  }
}

resource "google_container_cluster" "clusters" {
  for_each = var.clusters

  name     = each.key
  location = each.value.zone
  project  = var.project_id
  # Mantém a proteção contra deleção desativada para gerenciamento via Terraform.
  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  network = var.network
  
  # Seleciona a subnet correspondente à região do cluster
  # Valida que existe uma subnet para a região do cluster
  subnetwork = [for subnet_name, subnet in var.subnets : subnet.name
    if subnet.region == each.value.region][0]


  private_cluster_config {
    enable_private_nodes    = each.value.enable_private_nodes
    enable_private_endpoint = each.value.enable_private_endpoint
    # Usa CIDR único por cluster para evitar conflitos
    # master-engine: 172.16.0.0/28, app-engine: 172.16.1.0/28
    master_ipv4_cidr_block  = try(each.value.master_ipv4_cidr_block, 
      each.key == "master-engine" ? "172.16.0.0/28" : "172.16.1.0/28")
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(each.value.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = each.value.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  ip_allocation_policy {
    # Encontra a subnet correspondente à região do cluster e extrai os ranges secundários
    cluster_secondary_range_name = try([
      for subnet_name, subnet in var.subnets : [
        for sec_range in subnet.secondary_ip_ranges : sec_range.range_name
        if sec_range.range_name == "pods" && subnet.region == each.value.region
      ]
    ][0][0], "pods")
    
    services_secondary_range_name = try([
      for subnet_name, subnet in var.subnets : [
        for sec_range in subnet.secondary_ip_ranges : sec_range.range_name
        if sec_range.range_name == "services" && subnet.region == each.value.region
      ]
    ][0][0], "services")
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  network_policy {
    enabled = true
  }

  enable_intranode_visibility = true

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

    maintenance_policy {
      recurring_window {
        start_time = "2024-01-01T03:00:00Z"
        end_time   = "2024-01-01T15:00:00Z"
        recurrence = "FREQ=WEEKLY;BYDAY=SU"
      }
    }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Binary Authorization: usa DISABLED por padrão para não bloquear provisionamento
  # Se necessário, configure uma política no projeto e mude para PROJECT_SINGLETON_POLICY_ENFORCE
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  resource_labels = {
    environment = "production"
    managed-by  = "terraform"
  }

  timeouts {
    create = "45m"
    update = "45m"
    delete = "30m"
  }

  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      # Ignora mudanças em labels que podem ser feitas externamente
      resource_labels["updated-by"],
    ]
  }
}

resource "google_container_node_pool" "node_pools" {
  for_each = {
    for k, v in var.clusters : k => v
  }

  name       = "${each.key}-node-pool"
  location   = each.value.zone
  cluster    = google_container_cluster.clusters[each.key].name
  project    = var.project_id
  # Com autoscaling habilitado, o node_count inicial é usado apenas na criação
  # O autoscaler gerencia o número de nodes depois disso
  node_count = each.value.initial_node_count

  autoscaling {
    min_node_count = each.value.min_node_count
    max_node_count = each.value.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_size_gb    = each.value.disk_size_gb
    disk_type       = "pd-standard"
    image_type      = "COS_CONTAINERD"
    preemptible     = try(each.value.preemptible, false)
    service_account = try(each.value.service_account, null)

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      cluster = each.key
    }

    dynamic "taint" {
      for_each = try(each.value.taints, [])
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  depends_on = [google_container_cluster.clusters]

  lifecycle {
    # Ignora mudanças no node_count quando autoscaling está habilitado
    # O autoscaler gerencia o número de nodes dinamicamente
    ignore_changes = [
      node_count
    ]
    # Nota: machine_type não pode ser alterado em node pool existente
    # Se precisar mudar o machine_type, será necessário recriar o node pool
    # Use: terraform taint para forçar recriação ou delete o node pool manualmente
  }
}

