output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "network_self_link" {
  description = "The self link of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "subnets" {
  description = "The created subnets"
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
  description = "List of subnet names"
  value       = [for subnet in google_compute_subnetwork.subnets : subnet.name]
}

