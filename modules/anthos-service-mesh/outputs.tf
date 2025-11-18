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

output "multicluster_ingress_status" {
  description = "Status of Multi-cluster Ingress feature"
  value = {
    feature_state = google_gke_hub_feature.multicluster_ingress.state
    memberships = {
      for k, v in google_gke_hub_feature_membership.multicluster_ingress_membership : k => {
        membership = v.membership
      }
    }
  }
  sensitive = true
}

output "multicluster_services_status" {
  description = "Status of Multi-cluster Services feature"
  value = {
    feature_state = google_gke_hub_feature.multicluster_services.state
    memberships = {
      for k, v in google_gke_hub_feature_membership.multicluster_services_membership : k => {
        membership = v.membership
      }
    }
  }
  sensitive = true
}

output "membership_ids" {
  description = "Membership IDs for multi-cluster configuration"
  value = {
    for k, v in google_gke_hub_membership.memberships : k => v.membership_id
  }
}

