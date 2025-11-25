provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}


resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "gkehub.googleapis.com",
    "mesh.googleapis.com",
    "dns.googleapis.com",
    "certificatemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "networkservices.googleapis.com",
    "networksecurity.googleapis.com",
    "trafficdirector.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

module "vpc" {
  source = "./modules/vpc"

  project_id     = var.project_id
  network_name   = var.network_name
  manage_network = var.manage_network
  region         = var.region

  subnets = var.subnets

  enable_private_google_access = true

  secondary_ranges = var.secondary_ranges

  depends_on = [
    google_project_service.required_apis,
    module.gke_clusters,        # Garante que clusters sejam completamente deletados antes da VPC
    module.anthos_service_mesh  # Garante que ASM seja deletado antes da VPC
  ]
}

module "gke_clusters" {
  count = var.enable_gke ? 1 : 0

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

module "anthos_service_mesh" {
  count = var.enable_asm && var.enable_gke ? 1 : 0

  source = "./modules/anthos-service-mesh"

  project_id = var.project_id
  region     = var.region

  clusters = module.gke_clusters[0].cluster_registration_info

  depends_on = [
    google_project_service.required_apis,
    module.gke_clusters
  ]
}

module "dns" {
  source = "./modules/dns"

  project_id  = var.project_id
  domain_name = var.domain_name

  depends_on = [google_project_service.required_apis]
}

module "certificate" {
  source = "./modules/certificate"

  project_id    = var.project_id
  domain_name   = var.domain_name
  dns_zone_name = module.dns.zone_name

  depends_on = [
    google_project_service.required_apis,
    module.dns
  ]
}



