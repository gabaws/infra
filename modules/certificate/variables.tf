variable "project_id" {
  description = "ID do projeto GCP onde os recursos de certificado serão criados"
  type        = string
}

variable "domain_name" {
  description = "Domínio raiz (ex.: cloudab.online)"
  type        = string
}

variable "dns_zone_name" {
  description = "Nome da zona DNS onde os registros de validação serão criados"
  type        = string
}

