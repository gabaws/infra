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
  value       = module.gke_clusters.cluster_info
  sensitive   = true
}

output "anthos_service_mesh_status" {
  description = "Anthos Service Mesh configuration status"
  value       = module.anthos_service_mesh.mesh_status
  sensitive   = true
}

output "cluster_endpoints" {
  description = "GKE cluster endpoints"
  value = {
    for k, v in module.gke_clusters.cluster_info : k => {
      endpoint   = v.endpoint
      cluster_ca = v.cluster_ca_certificate
    }
  }
  sensitive = true
}

output "dns_nameservers" {
  description = "Nameservers do Cloud DNS da zona pública (aponte no GoDaddy)"
  value       = try(module.dns_and_cert.nameservers, [])
}

output "certificate_manager_certificate" {
  description = "Identificador do certificado gerenciado (wildcard)"
  value       = try(module.dns_and_cert.certificate_name, null)
}
