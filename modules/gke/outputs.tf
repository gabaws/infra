output "cluster_info" {
  description = "Information about the created GKE clusters"
  value = {
    for k, v in google_container_cluster.clusters : k => {
      name                = v.name
      endpoint            = v.endpoint
      cluster_ca_certificate = v.master_auth[0].cluster_ca_certificate
      location            = v.location
      network             = v.network
      subnetwork          = v.subnetwork
      node_pool_name      = google_container_node_pool.node_pools[k].name
    }
  }
  sensitive = true
}

output "cluster_names" {
  description = "Names of the created clusters"
  value       = [for k, v in google_container_cluster.clusters : v.name]
}

output "cluster_endpoints" {
  description = "Endpoints of the created clusters"
  value = {
    for k, v in google_container_cluster.clusters : k => v.endpoint
  }
  sensitive = true
}

