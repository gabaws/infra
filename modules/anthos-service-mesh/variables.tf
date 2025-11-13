variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The default region for resources"
  type        = string
}

variable "clusters" {
  description = "Information about GKE clusters to register with Anthos Service Mesh"
  type = map(object({
    name     = string
    location = string
    endpoint = string
  }))
}

