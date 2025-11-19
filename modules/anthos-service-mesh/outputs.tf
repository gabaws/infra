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
    note          = "MCS feature is enabled, but config_membership must be configured manually via gcloud"
  }
  sensitive = false
}

output "mcs_setup_command" {
  description = "Comando para configurar o MCS após o Terraform"
  value = <<-EOT
    # 1. Obter o membership ID do primeiro cluster (config cluster)
    CONFIG_MEMBERSHIP=$(terraform output -json | jq -r '.anthos_service_mesh_status.value.membership_ids | to_entries[0].value')
    
    # 2. Habilitar MCS
    gcloud container fleet multi-cluster-services enable --project=${var.project_id}
    
    # 3. Configurar config_membership
    gcloud container fleet multi-cluster-services update \\
      --config-membership=projects/${var.project_id}/locations/global/memberships/\$CONFIG_MEMBERSHIP \\
      --project=${var.project_id}
    
    # 4. Registrar todos os clusters
    MEMBERSHIPS=$(terraform output -json | jq -r '.anthos_service_mesh_status.value.membership_ids | to_entries | map(.value) | join(",")')
    gcloud container fleet multi-cluster-services update \\
      --config-membership=projects/${var.project_id}/locations/global/memberships/\$CONFIG_MEMBERSHIP \\
      --memberships=\$MEMBERSHIPS \\
      --project=${var.project_id}
  EOT
  sensitive = false
}

