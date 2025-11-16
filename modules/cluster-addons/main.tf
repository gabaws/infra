terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11"
    }
  }
}

locals {
  argocd_values_yaml = var.install_argocd && length(var.argocd_values) > 0 ? [yamlencode(var.argocd_values)] : []
}

resource "helm_release" "argocd" {
  count            = var.install_argocd ? 1 : 0
  name             = "${var.cluster_name}-argocd"
  repository       = var.argocd_repository
  chart            = var.argocd_chart
  namespace        = var.argocd_namespace
  version          = var.argocd_chart_version
  create_namespace = true
  values           = local.argocd_values_yaml
  cleanup_on_fail  = true
  timeout          = var.helm_release_timeout
  wait             = var.helm_wait
}
