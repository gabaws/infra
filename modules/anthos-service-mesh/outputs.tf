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
}

output "membership_names" {
  description = "Names of GKE Hub memberships"
  value       = { for k, v in google_gke_hub_membership.memberships : k => v.name }
}

