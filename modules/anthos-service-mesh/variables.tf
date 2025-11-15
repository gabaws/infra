variable "project_id" {
  description = "ID do projeto GCP onde o ASM será configurado"
  type        = string
}

variable "region" {
  description = "Região padrão (usada apenas para consistência)"
  type        = string
}

variable "clusters" {
  description = "Informações mínimas dos clusters GKE que serão registrados no Anthos Service Mesh"
  type = map(object({
    name     = string
    location = string
  }))
}

