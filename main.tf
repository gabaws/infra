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

# DNS público + Certificado gerenciado (wildcard) para o domínio raiz
module "dns_and_cert" {
  source = "./modules/dns-cert"

  project_id  = var.project_id
  domain_name = var.domain_name

  depends_on = [google_project_service.required_apis]
}

locals {
  cluster_addons = {
    master = {
      name = var.primary_cluster_name
      info = module.gke_clusters.cluster_info[var.primary_cluster_name]
    }
    app = {
      name = var.secondary_cluster_name
      info = module.gke_clusters.cluster_info[var.secondary_cluster_name]
    }
  }
}

provider "kubernetes" {
  alias                  = "master"
  host                   = "https://${local.cluster_addons.master.info.endpoint}"
  cluster_ca_certificate = base64decode(local.cluster_addons.master.info.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "kubernetes" {
  alias                  = "app"
  host                   = "https://${local.cluster_addons.app.info.endpoint}"
  cluster_ca_certificate = base64decode(local.cluster_addons.app.info.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  alias = "master"
  kubernetes = {
    host                   = "https://${local.cluster_addons.master.info.endpoint}"
    cluster_ca_certificate = base64decode(local.cluster_addons.master.info.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

provider "helm" {
  alias = "app"
  kubernetes = {
    host                   = "https://${local.cluster_addons.app.info.endpoint}"
    cluster_ca_certificate = base64decode(local.cluster_addons.app.info.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

module "master_cluster_addons" {
  count  = var.enable_cluster_addons ? 1 : 0
  source = "./modules/cluster-addons"

  cluster_name                      = local.cluster_addons.master.info.name
  istio_namespace                   = var.istio_namespace
  manage_istio_namespace            = var.manage_istio_namespace
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
  install_argocd                    = var.install_argocd && local.cluster_addons.master.name == var.argocd_target_cluster
  create_argocd_gateway             = var.create_argocd_gateway && local.cluster_addons.master.name == var.argocd_target_cluster
  argocd_host                       = var.argocd_host
  argocd_chart_version              = var.argocd_chart_version
  argocd_namespace                  = var.argocd_namespace
  argocd_values                     = var.argocd_values
  argocd_chart                      = var.argocd_chart
  argocd_repository                 = var.argocd_repository
  istio_repository                  = var.istio_repository
  helm_release_timeout              = var.helm_release_timeout
  helm_wait                         = var.helm_wait

  providers = {
    kubernetes = kubernetes.master
    helm       = helm.master
  }

  depends_on = [
    module.gke_clusters,
    module.anthos_service_mesh
  ]
}

module "app_cluster_addons" {
  count  = var.enable_cluster_addons ? 1 : 0
  source = "./modules/cluster-addons"

  cluster_name                      = local.cluster_addons.app.info.name
  istio_namespace                   = var.istio_namespace
  manage_istio_namespace            = var.manage_istio_namespace
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
  install_argocd                    = var.install_argocd && local.cluster_addons.app.name == var.argocd_target_cluster
  argocd_chart_version              = var.argocd_chart_version
  argocd_namespace                  = var.argocd_namespace
  argocd_values                     = var.argocd_values
  argocd_chart                      = var.argocd_chart
  argocd_repository                 = var.argocd_repository
  istio_repository                  = var.istio_repository
  helm_release_timeout              = var.helm_release_timeout
  helm_wait                         = var.helm_wait

  providers = {
    kubernetes = kubernetes.app
    helm       = helm.app
  }

  depends_on = [
    module.gke_clusters,
    module.anthos_service_mesh
  ]
}

