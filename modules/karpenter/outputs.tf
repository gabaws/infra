output "karpenter_service_accounts" {
  description = "Service Accounts do GCP criados para o Karpenter"
  value = {
    for k, v in google_service_account.karpenter : k => {
      email = v.email
      name  = v.name
    }
  }
}

output "karpenter_namespace" {
  description = "Namespace onde o Karpenter foi instalado"
  value       = var.karpenter_namespace
}

output "karpenter_installed_clusters" {
  description = "Clusters onde o Karpenter foi instalado"
  value       = keys(var.clusters)
}

