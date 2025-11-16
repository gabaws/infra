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

# (ASM Gerenciado) Gateway API para expor o ArgoCD no cluster alvo
# Usa o GatewayClass gerenciado do GKE (externo global). Opcionalmente
# aplica hostname se var.argocd_host != "".
resource "kubernetes_manifest" "argocd_gateway" {
  count = var.install_argocd && var.create_argocd_gateway ? 1 : 0
  manifest = merge(
    {
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "Gateway"
      metadata = {
        name      = "argocd-gw"
        namespace = var.argocd_namespace
      }
      spec = {
        gatewayClassName = "gke-l7-global-external-managed"
        listeners = [
          merge(
            {
              name     = "http"
              protocol = "HTTP"
              port     = 80
              allowedRoutes = {
                namespaces = { from = "Same" }
              }
            },
            var.argocd_host != "" ? { hostname = var.argocd_host } : {}
          )
        ]
      }
    },
    {}
  )
}

resource "kubernetes_manifest" "argocd_route" {
  count = var.install_argocd && var.create_argocd_gateway ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd-route"
      namespace = var.argocd_namespace
    }
    spec = {
      parentRefs = [{
        name      = kubernetes_manifest.argocd_gateway[0].manifest.metadata.name
        namespace = var.argocd_namespace
      }]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "argocd-server"
          port = 80
        }]
      }]
    }
  }
  depends_on = [helm_release.argocd, kubernetes_manifest.argocd_gateway]
}
