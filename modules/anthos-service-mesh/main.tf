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

# Multi-cluster Ingress Feature
# NOTE: The multiclusteringress feature requires a config_membership which cannot be
# set via Terraform currently. This feature must be enabled manually via gcloud:
#
# gcloud container fleet ingress enable \
#   --config-membership=projects/PROJECT_ID/locations/global/memberships/MEMBERSHIP_ID \
#   --project=PROJECT_ID
#
# After enabling, you can register clusters to the feature:
# gcloud container fleet ingress update \
#   --config-membership=projects/PROJECT_ID/locations/global/memberships/MEMBERSHIP_ID \
#   --memberships=MEMBERSHIP_ID_1,MEMBERSHIP_ID_2 \
#   --project=PROJECT_ID
#
# See: https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress-setup

