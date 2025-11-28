variable "project_id" {
  description = "ID do projeto GCP onde as regras de firewall serão criadas"
  type        = string
}

variable "network_name" {
  description = "Nome da rede VPC onde as regras serão aplicadas"
  type        = string
}

variable "subnets" {
  description = "Lista de subnets com seus CIDRs para permitir tráfego bidirecional"
  type = list(object({
    name          = string
    ip_cidr_range = string
    region        = string
    description   = optional(string)
  }))
}

variable "clusters" {
  description = "Mapa de clusters com suas configurações (nome, região, etc.). Usado apenas para referência nas descrições."
  type = map(object({
    region = string
    zone   = string
  }))
  default = {}
}

