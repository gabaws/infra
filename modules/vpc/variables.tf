variable "project_id" {
  description = "ID do projeto GCP onde a VPC será criada"
  type        = string
}

variable "network_name" {
  description = "Nome da rede VPC"
  type        = string
}

variable "manage_network" {
  description = "Quando false, reutiliza a VPC informada em vez de criar uma nova"
  type        = bool
  default     = true
}

variable "region" {
  description = "Região padrão usada nos recursos auxiliares (ex.: Cloud NAT)"
  type        = string
}

variable "subnets" {
  description = "Lista de sub-redes que serão criadas"
  type = list(object({
    name          = string
    ip_cidr_range = string
    region        = string
    description   = optional(string)
  }))
}

variable "secondary_ranges" {
  description = "Faixas secundárias de IP usadas por pods/serviços GKE"
  type = map(list(object({
    range_name    = string
    ip_cidr_range = string
  })))
  default = {}
}

variable "enable_private_google_access" {
  description = "Ativa o Private Google Access nas sub-redes"
  type        = bool
  default     = true
}

variable "enable_cloud_nat" {
  description = "Ativa Cloud NAT para sub-redes privadas"
  type        = bool
  default     = true
}

variable "enable_ssh" {
  description = "Habilita regra de firewall para SSH (uso emergencial)"
  type        = bool
  default     = false
}

variable "ssh_source_ranges" {
  description = "CIDRs de origem autorizados a usar SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

