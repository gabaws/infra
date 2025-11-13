# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "gkehub.googleapis.com",
    "mesh.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_id     = var.project_id
  network_name   = var.network_name
  manage_network = var.manage_network
  region         = var.region

  subnets = var.subnets

  # Private Google Access
  enable_private_google_access = true

  # Secondary ranges for GKE pods and services
  secondary_ranges = var.secondary_ranges

  depends_on = [google_project_service.required_apis]
}

# GKE Clusters Module
module "gke_clusters" {
  source = "./modules/gke"

  project_id = var.project_id
  region     = var.region
  network    = module.vpc.network_name
  subnets    = module.vpc.subnets

  clusters = var.gke_clusters

  depends_on = [
    google_project_service.required_apis,
    module.vpc
  ]
}

# Anthos Service Mesh Module
module "anthos_service_mesh" {
  source = "./modules/anthos-service-mesh"

  project_id = var.project_id
  region     = var.region

  clusters = module.gke_clusters.cluster_registration_info

  depends_on = [
    google_project_service.required_apis,
    module.gke_clusters
  ]
}

