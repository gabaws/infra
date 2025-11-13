# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

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

locals {
  cluster_addons = {
    cluster1 = {
      name = "cluster-1"
      info = module.gke_clusters.cluster_info["cluster-1"]
    }
    cluster2 = {
      name = "cluster-2"
      info = module.gke_clusters.cluster_info["cluster-2"]
    }
  }
}

provider "kubernetes" {
  alias                  = "cluster1"
  host                   = "https://${local.cluster_addons.cluster1.info.endpoint}"
  cluster_ca_certificate = base64decode(local.cluster_addons.cluster1.info.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}

provider "kubernetes" {
  alias                  = "cluster2"
  host                   = "https://${local.cluster_addons.cluster2.info.endpoint}"
  cluster_ca_certificate = base64decode(local.cluster_addons.cluster2.info.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}

provider "helm" {
  alias = "cluster1"
  kubernetes {
    host                   = "https://${local.cluster_addons.cluster1.info.endpoint}"
    cluster_ca_certificate = base64decode(local.cluster_addons.cluster1.info.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

provider "helm" {
  alias = "cluster2"
  kubernetes {
    host                   = "https://${local.cluster_addons.cluster2.info.endpoint}"
    cluster_ca_certificate = base64decode(local.cluster_addons.cluster2.info.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

module "cluster1_addons" {
  source = "./modules/cluster-addons"

  cluster_name                      = local.cluster_addons.cluster1.info.name
  istio_namespace                   = var.istio_namespace
  asm_revision                      = var.asm_revision
  istio_chart_version               = var.istio_chart_version
  istiod_values                     = var.istiod_values
  install_gateway                   = var.install_gateway
  istio_gateway_chart               = var.istio_gateway_chart
  gateway_namespace                 = var.gateway_namespace
  istio_gateway_values              = var.istio_gateway_values
  additional_istio_namespace_labels = var.additional_istio_namespace_labels
  gateway_namespace_labels          = var.gateway_namespace_labels
  gateway_labels                    = var.gateway_labels
  install_argocd                    = var.install_argocd
  argocd_chart_version              = var.argocd_chart_version
  argocd_namespace                  = var.argocd_namespace
  argocd_values                     = var.argocd_values
  argocd_chart                      = var.argocd_chart
  argocd_repository                 = var.argocd_repository
  istio_repository                  = var.istio_repository

  providers = {
    kubernetes = kubernetes.cluster1
    helm       = helm.cluster1
  }

  depends_on = [
    module.gke_clusters,
    module.anthos_service_mesh
  ]
}

module "cluster2_addons" {
  source = "./modules/cluster-addons"

  cluster_name                      = local.cluster_addons.cluster2.info.name
  istio_namespace                   = var.istio_namespace
  asm_revision                      = var.asm_revision
  istio_chart_version               = var.istio_chart_version
  istiod_values                     = var.istiod_values
  install_gateway                   = var.install_gateway
  istio_gateway_chart               = var.istio_gateway_chart
  gateway_namespace                 = var.gateway_namespace
  istio_gateway_values              = var.istio_gateway_values
  additional_istio_namespace_labels = var.additional_istio_namespace_labels
  gateway_namespace_labels          = var.gateway_namespace_labels
  gateway_labels                    = var.gateway_labels
  install_argocd                    = var.install_argocd
  argocd_chart_version              = var.argocd_chart_version
  argocd_namespace                  = var.argocd_namespace
  argocd_values                     = var.argocd_values
  argocd_chart                      = var.argocd_chart
  argocd_repository                 = var.argocd_repository
  istio_repository                  = var.istio_repository

  providers = {
    kubernetes = kubernetes.cluster2
    helm       = helm.cluster2
  }

  depends_on = [
    module.gke_clusters,
    module.anthos_service_mesh
  ]
}

