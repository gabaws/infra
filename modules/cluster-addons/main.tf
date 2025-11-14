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
  istio_namespace_labels = merge(
    {
      "istio.io/rev" = var.asm_revision
    },
    var.additional_istio_namespace_labels
  )

  istiod_values = merge(
    {
      revision = var.asm_revision
    },
    var.istiod_values
  )

  istio_gateway_values = merge(
    {
      revision = var.asm_revision
      labels = merge(
        {
          "istio"      = "ingressgateway"
          "istio.io/rev" = var.asm_revision
        },
        var.gateway_labels
      )
    },
    var.istio_gateway_values
  )

  argocd_values_yaml = var.install_argocd && length(var.argocd_values) > 0 ? [yamlencode(var.argocd_values)] : []
  istiod_values_yaml = length(local.istiod_values) > 0 ? [yamlencode(local.istiod_values)] : []
  istio_gateway_values_yaml = var.install_gateway && length(local.istio_gateway_values) > 0 ? [yamlencode(local.istio_gateway_values)] : []
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name   = var.istio_namespace
    labels = local.istio_namespace_labels
  }
}

resource "helm_release" "istio_base" {
  name             = "${var.cluster_name}-istio-base"
  repository       = var.istio_repository
  chart            = "base"
  namespace        = var.istio_namespace
  version          = var.istio_chart_version
  create_namespace = false

  depends_on = [
    kubernetes_namespace.istio_system
  ]
}

resource "helm_release" "istiod" {
  name       = "${var.cluster_name}-istiod"
  repository = var.istio_repository
  chart      = "istiod"
  namespace  = var.istio_namespace
  version    = var.istio_chart_version

  values = local.istiod_values_yaml

  depends_on = [
    helm_release.istio_base
  ]
}

resource "helm_release" "istio_gateway" {
  count      = var.install_gateway ? 1 : 0
  name       = "${var.cluster_name}-istio-ingressgateway"
  repository = var.istio_repository
  chart      = var.istio_gateway_chart
  namespace  = var.gateway_namespace != "" ? var.gateway_namespace : var.istio_namespace
  version    = var.istio_chart_version

  create_namespace = false
  values           = local.istio_gateway_values_yaml

  depends_on = [
    helm_release.istiod,
    kubernetes_namespace.gateway
  ]
}

resource "kubernetes_namespace" "gateway" {
  count = var.install_gateway && var.gateway_namespace != "" && var.gateway_namespace != var.istio_namespace ? 1 : 0

  metadata {
    name = var.gateway_namespace
    labels = merge(
      {
        "istio.io/rev" = var.asm_revision
      },
      var.gateway_namespace_labels
    )
  }
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

  depends_on = [
    helm_release.istio_base
  ]
}
