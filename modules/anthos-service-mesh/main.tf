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

# Enable Mesh API
resource "google_project_service" "mesh_api" {
  project = var.project_id
  service = "mesh.googleapis.com"

  disable_on_destroy = false
}

# Enable GKE Hub API
resource "google_project_service" "gkehub_api" {
  project = var.project_id
  service = "gkehub.googleapis.com"

  disable_on_destroy = false
}

# GKE Hub Membership for each cluster
resource "google_gke_hub_membership" "memberships" {
  for_each = var.clusters

  membership_id = "${each.key}-membership"
  project       = var.project_id
  location      = "global"

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${var.project_id}/locations/${each.value.location}/clusters/${each.value.name}"
    }
  }

  depends_on = [
    google_project_service.gkehub_api,
    google_project_service.mesh_api
  ]
}

# Feature for Anthos Service Mesh
resource "google_gke_hub_feature" "mesh" {
  name     = "servicemesh"
  location = "global"
  project  = var.project_id

  depends_on = [
    google_project_service.mesh_api,
    google_project_service.gkehub_api,
    google_gke_hub_membership.memberships
  ]
}

# Feature Membership for each cluster
resource "google_gke_hub_feature_membership" "mesh_feature_membership" {
  for_each = var.clusters

  location   = "global"
  feature    = google_gke_hub_feature.mesh.name
  membership = google_gke_hub_membership.memberships[each.key].membership_id
  project    = var.project_id

  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }

  depends_on = [
    google_gke_hub_feature.mesh,
    google_gke_hub_membership.memberships
  ]
}

# Multi-cluster Services (MCS) Feature
# Habilita o Multi-cluster Services para permitir ServiceExport/ServiceImport entre clusters
# NOTA: O Terraform não suporta completamente a configuração do MCS via feature_membership.
# A feature é habilitada aqui, mas a configuração do config_membership deve ser feita manualmente via gcloud.
resource "google_gke_hub_feature" "multiclusterservicediscovery" {
  name     = "multiclusterservicediscovery"
  location = "global"
  project  = var.project_id

  depends_on = [
    google_project_service.gkehub_api,
    google_gke_hub_membership.memberships
  ]
}

