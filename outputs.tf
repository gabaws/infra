output "project_id" {
  description = "The ID of the project being used"
  value       = var.project_id
}

output "network_name" {
  description = "The name of the VPC network"
  value       = module.vpc.network_name
}

output "network_self_link" {
  description = "The self link of the VPC network"
  value       = module.vpc.network_self_link
}

output "subnets" {
  description = "The created subnets"
  value       = module.vpc.subnets
}

output "gke_clusters" {
  description = "GKE cluster information"
  value       = var.enable_gke ? module.gke_clusters[0].cluster_info : null
  sensitive   = true
}

output "anthos_service_mesh_status" {
  description = "Anthos Service Mesh configuration status"
  value       = var.enable_asm && var.enable_gke ? module.anthos_service_mesh[0].mesh_status : null
  sensitive   = true
}

# Multi-cluster Ingress output removed - feature must be enabled manually
# See modules/anthos-service-mesh/main.tf for instructions

output "gke_hub_membership_ids" {
  description = "GKE Hub membership IDs for multi-cluster configuration"
  value       = var.enable_asm && var.enable_gke ? module.anthos_service_mesh[0].membership_ids : null
}

output "cluster_endpoints" {
  description = "GKE cluster endpoints"
  value = var.enable_gke ? {
    for k, v in module.gke_clusters[0].cluster_info : k => {
      endpoint   = v.endpoint
      cluster_ca = v.cluster_ca_certificate
    }
  } : null
  sensitive = true
}

output "dns_nameservers" {
  description = "Nameservers do Cloud DNS da zona pública (aponte no GoDaddy)"
  value       = try(module.dns.nameservers, [])
}

output "certificate_manager_certificate" {
  description = "Identificador do certificado gerenciado (wildcard)"
  value       = try(module.certificate.certificate_name, null)
}

output "certificate_map_id" {
  description = "ID completo do Certificate Map para uso no Gateway API"
  value       = try(module.certificate.certificate_map_id, null)
}

