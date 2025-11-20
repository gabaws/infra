output "project_id" {
  description = "ID do projeto usado"
  value       = var.project_id
}

output "network_name" {
  description = "Nome da VPC"
  value       = module.vpc.network_name
}

output "network_self_link" {
  description = "O link próprio da rede VPC"
  value       = module.vpc.network_self_link
}

output "subnets" {
  description = "Subnets criadas"
  value       = module.vpc.subnets
}

output "gke_clusters" {
  description = "Informações do cluster GKE"
  value       = var.enable_gke ? module.gke_clusters[0].cluster_info : null
  sensitive   = true
}

output "anthos_service_mesh_status" {
  description = "Status de configuração do Anthos Service Mesh"
  value       = var.enable_asm && var.enable_gke ? module.anthos_service_mesh[0].mesh_status : null
  sensitive   = true
}

output "gke_hub_membership_ids" {
  description = "IDs de associação do GKE Hub para configuração de vários clusters"
  value       = var.enable_asm && var.enable_gke ? module.anthos_service_mesh[0].membership_ids : null
}

output "cluster_endpoints" {
  description = "Enpoints clusters GKE"
  value = var.enable_gke ? {
    for k, v in module.gke_clusters[0].cluster_info : k => {
      endpoint   = v.endpoint
      cluster_ca = v.cluster_ca_certificate
    }
  } : null
  sensitive = true
}

output "dns_nameservers" {
  description = "Nameservers do Cloud DNS da zona pública"
  value       = try(module.dns.nameservers, [])
}

output "certificate_manager_certificate" {
  description = "Identificador do certificado gerenciado (wildcard)"
  value       = try(module.certificate.certificate_name, null)
}

output "certificate_map_id" {
  description = "ID completo do Certificate Map"
  value       = try(module.certificate.certificate_map_id, null)
}

