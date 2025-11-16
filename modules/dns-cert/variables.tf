variable "project_id" {
  description = "ID do projeto GCP onde os recursos de DNS/Certificados serão criados"
  type        = string
}

variable "domain_name" {
  description = "Domínio raiz (ex.: cloudab.online)"
  type        = string
}


