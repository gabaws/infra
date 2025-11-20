output "network_name" {
  description = "Nome da VPC"
  value       = local.network_name
}

output "network_id" {
  description = "ID da VPC"
  value       = local.network_id
}

output "network_self_link" {
  description = "O link próprio da rede VPC"
  value       = local.network_self_link
}

output "subnets" {
  description = "Subnets criadas"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => {
      name                = v.name
      id                  = v.id
      ip_cidr_range       = v.ip_cidr_range
      region              = v.region
      self_link           = v.self_link
      secondary_ip_ranges = v.secondary_ip_range
    }
  }
}

output "subnet_names" {
  description = "Lista e Nome das Subnets"
  value       = [for subnet in google_compute_subnetwork.subnets : subnet.name]
}

