variable "project_id" {
  description = "ID do projeto GCP onde a zona DNS será criada"
  type        = string
}

variable "domain_name" {
  description = "Domínio raiz (ex.: cloudab.online)"
  type        = string
}

