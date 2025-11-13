terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.41"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.41"
    }
  }
}

# GKE Clusters
resource "google_container_cluster" "clusters" {
  for_each = var.clusters

  name     = each.key
  location = each.value.zone
  project  = var.project_id

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration - find subnet matching cluster region
  network = var.network
  subnetwork = [
    for subnet_name, subnet in var.subnets : subnet.name
    if subnet.region == each.value.region
  ][0]

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = each.value.enable_private_nodes
    enable_private_endpoint = each.value.enable_private_endpoint
    master_ipv4_cidr_block  = try(each.value.master_ipv4_cidr_block, "172.16.0.0/28")
  }

  # Master authorized networks
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

  # IP allocation policy for pods and services
  ip_allocation_policy {
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

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel
  release_channel {
    channel = "REGULAR"
  }

  # Network policy
  network_policy {
    enabled = true
  }

  # Addons
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

  # Maintenance window
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T03:00:00Z"
      end_time   = "2024-01-01T05:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Binary authorization (optional)
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Resource labels
  resource_labels = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# Node pools for each cluster
resource "google_container_node_pool" "node_pools" {
  for_each = {
    for k, v in var.clusters : k => v
  }

  name       = "${each.key}-node-pool"
  location   = each.value.zone
  cluster    = google_container_cluster.clusters[each.key].name
  project    = var.project_id
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

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    # Labels
    labels = {
      cluster = each.key
    }

    # Taints (optional)
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
}

