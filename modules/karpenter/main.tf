terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

# Data source para obter credenciais do cluster
data "google_container_cluster" "clusters" {
  for_each = var.clusters

  name     = each.value.cluster_name
  location = each.value.cluster_location
  project  = var.project_id
}

data "google_client_config" "default" {}

# Service Account para o Karpenter
resource "google_service_account" "karpenter" {
  for_each = var.clusters

  account_id   = "karpenter-${each.key}"
  display_name = "Karpenter Service Account for ${each.key}"
  project      = var.project_id
}

# IAM Binding para o Karpenter criar e gerenciar nodes
resource "google_project_iam_member" "karpenter_compute_admin" {
  for_each = var.clusters

  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.karpenter[each.key].email}"
}

resource "google_project_iam_member" "karpenter_storage_admin" {
  for_each = var.clusters

  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.karpenter[each.key].email}"
}

resource "google_project_iam_member" "karpenter_service_account_user" {
  for_each = var.clusters

  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.karpenter[each.key].email}"
}

# Workload Identity Binding para o Karpenter usar Workload Identity
resource "google_service_account_iam_member" "karpenter_workload_identity" {
  for_each = var.clusters

  service_account_id = google_service_account.karpenter[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.karpenter_namespace}/karpenter]"
}

# Namespace para o Karpenter em cada cluster usando arquivo YAML
resource "null_resource" "karpenter_namespace" {
  for_each = var.clusters

  triggers = {
    cluster_name     = each.value.cluster_name
    cluster_location = each.value.cluster_location
    namespace        = var.karpenter_namespace
    yaml_content = templatefile("${path.module}/manifests/namespace.yaml", {
      namespace = var.karpenter_namespace
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${each.value.cluster_name} \
        --location=${each.value.cluster_location} \
        --project=${var.project_id} && \
      cat <<'EOF' | kubectl apply -f -
${templatefile("${path.module}/manifests/namespace.yaml", {
    namespace = var.karpenter_namespace
})}
EOF
    EOT
}

depends_on = [data.google_container_cluster.clusters]
}

# Service Account Kubernetes para o Karpenter usando arquivo YAML
resource "null_resource" "karpenter_service_account" {
  for_each = var.clusters

  triggers = {
    cluster_name     = each.value.cluster_name
    cluster_location = each.value.cluster_location
    namespace        = var.karpenter_namespace
    sa_email         = google_service_account.karpenter[each.key].email
    yaml_content = templatefile("${path.module}/manifests/serviceaccount.yaml", {
      namespace                 = var.karpenter_namespace
      gcp_service_account_email = google_service_account.karpenter[each.key].email
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${each.value.cluster_name} \
        --location=${each.value.cluster_location} \
        --project=${var.project_id} && \
      cat <<'EOF' | kubectl apply -f -
${templatefile("${path.module}/manifests/serviceaccount.yaml", {
    namespace                 = var.karpenter_namespace
    gcp_service_account_email = google_service_account.karpenter[each.key].email
})}
EOF
    EOT
}

depends_on = [
  null_resource.karpenter_namespace,
  google_service_account_iam_member.karpenter_workload_identity
]
}

# Helm Release para instalar o Karpenter usando helm
resource "null_resource" "karpenter_helm_install" {
  for_each = var.clusters

  triggers = {
    cluster_name     = each.value.cluster_name
    cluster_location = each.value.cluster_location
    version          = var.karpenter_version
    sa_email         = google_service_account.karpenter[each.key].email
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${each.value.cluster_name} \
        --location=${each.value.cluster_location} \
        --project=${var.project_id} && \
      helm upgrade --install karpenter ${var.karpenter_helm_repo}/karpenter \
        --version ${var.karpenter_version} \
        --namespace ${var.karpenter_namespace} \
        --create-namespace \
        --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"=${google_service_account.karpenter[each.key].email} \
        --set settings.clusterName=${each.value.cluster_name} \
        --set settings.defaultInstanceTypes="{${join(",", var.default_instance_types)}}" \
        --set settings.interruptionQueue="${var.interruption_queue}" \
        --set nodeSelector."kubernetes\.io/os"=linux \
        ${join(" ", [for k, v in var.additional_helm_values : "--set ${k}=${v}"])}
    EOT
  }

  depends_on = [
    null_resource.karpenter_namespace,
    null_resource.karpenter_service_account,
    google_service_account_iam_member.karpenter_workload_identity
  ]
}
