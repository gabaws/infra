output "mesh_status" {
  description = "Status of Anthos Service Mesh configuration"
  value = {
    feature_state = google_gke_hub_feature.mesh.state
    memberships = {
      for k, v in google_gke_hub_membership.memberships : k => {
        membership_id = v.membership_id
        name          = v.name
      }
    }
  }
  sensitive = true
}

output "membership_names" {
  description = "Names of GKE Hub memberships"
  value       = { for k, v in google_gke_hub_membership.memberships : k => v.name }
  sensitive   = true
}

# Multi-cluster Ingress output removed - feature must be enabled manually
# See main.tf for instructions on how to enable via gcloud

output "membership_ids" {
  description = "Membership IDs for multi-cluster configuration"
  value = {
    for k, v in google_gke_hub_membership.memberships : k => v.membership_id
  }
}

output "mcs_status" {
  description = "Status of Multi-cluster Services (MCS) feature"
  value = {
    feature_state = try(google_gke_hub_feature.multiclusterservicediscovery.state, null)
    enabled       = try(google_gke_hub_feature.multiclusterservicediscovery.state != null, false)
  }
  sensitive = true
}

