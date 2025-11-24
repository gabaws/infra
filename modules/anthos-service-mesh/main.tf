terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.0"
    }
  }
}

# GKE Hub Membership for each cluster
# As APIs mesh.googleapis.com e gkehub.googleapis.com já são habilitadas no main.tf
# Usa provider google-beta para garantir sincronização correta com o Fleet
resource "google_gke_hub_membership" "memberships" {
  provider = google-beta
  
  for_each = var.clusters

  membership_id = "${each.key}-membership"
  project       = var.project_id
  location      = "global"

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${var.project_id}/locations/${each.value.location}/clusters/${each.value.name}"
    }
  }
}

# Feature for Anthos Service Mesh
# Usa provider google-beta para garantir suporte completo ao Cloud Service Mesh
resource "google_gke_hub_feature" "mesh" {
  provider = google-beta
  
  name     = "servicemesh"
  location = "global"
  project  = var.project_id

  depends_on = [
    google_gke_hub_membership.memberships
  ]

  lifecycle {
    # Garante que os feature memberships sejam deletados antes do feature
    create_before_destroy = false
  }
}

# Null resource para forçar deleção do feature mesh via gcloud
# Este recurso depende do feature, então será destruído ANTES do feature durante a destruição
# Executando o comando gcloud durante sua destruição para limpar recursos associados
resource "null_resource" "force_delete_mesh_feature" {
  triggers = {
    project_id = var.project_id
    location   = "global"
    # Recria quando os clusters mudam
    clusters = join(",", [for k, v in var.clusters : "${k}:${v.name}"])
    # Inclui o ID do feature para forçar recriação quando necessário
    feature_id = google_gke_hub_feature.mesh.id
  }

  provisioner "local-exec" {
    when    = destroy
    command = "gcloud container hub features delete servicemesh --project=${self.triggers.project_id} --location=${self.triggers.location} --force --quiet || true"
  }

  depends_on = [
    google_gke_hub_feature.mesh
  ]
}

# Feature Membership for each cluster
# Registra cada cluster no Anthos Service Mesh com gerenciamento automático
# Usa provider google-beta para garantir suporte completo ao Cloud Service Mesh
resource "google_gke_hub_feature_membership" "mesh_feature_membership" {
  provider = google-beta
  
  for_each = var.clusters

  location   = "global"
  feature    = google_gke_hub_feature.mesh.name
  membership = google_gke_hub_membership.memberships[each.key].membership_id
  project    = var.project_id

  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }

  depends_on = [
    google_gke_hub_feature.mesh,
    google_gke_hub_membership.memberships
  ]

  lifecycle {
    # Garante que os memberships sejam deletados antes do feature
    create_before_destroy = false
  }
}


