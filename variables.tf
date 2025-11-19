variable "project_id" {
  description = "ID do projeto GCP que será usado (projeto existente)"
  type        = string
  default     = "infra-474223"
}

variable "region" {
  description = "Região padrão onde os recursos serão provisionados"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Nome da rede VPC"
  type        = string
  default     = "main-vpc"
}

variable "manage_network" {
  description = "Quando false, reaproveita uma VPC existente em vez de criar outra"
  type        = bool
  default     = true
}

variable "subnets" {
  description = "Lista de sub-redes que serão criadas"
  type = list(object({
    name          = string
    ip_cidr_range = string
    region        = string
    description   = optional(string)
  }))
  default = [
    {
      name          = "subnet-us-central1"
      ip_cidr_range = "10.0.1.0/24"
      region        = "us-central1"
      description   = "Subnet para a região us-central1"
    },
    {
      name          = "subnet-us-east1"
      ip_cidr_range = "10.0.2.0/24"
      region        = "us-east1"
      description   = "Subnet para a região us-east1"
    }
  ]
}

variable "secondary_ranges" {
  description = "Faixas secundárias de IP usadas pelos pods e serviços do GKE"
  type = map(list(object({
    range_name    = string
    ip_cidr_range = string
  })))
  default = {
    "subnet-us-central1" = [
      {
        range_name    = "pods"
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = "services"
        ip_cidr_range = "10.2.0.0/20"
      }
    ]
    "subnet-us-east1" = [
      {
        range_name    = "pods"
        ip_cidr_range = "10.3.0.0/16"
      },
      {
        range_name    = "services"
        ip_cidr_range = "10.4.0.0/20"
      }
    ]
  }
}

variable "primary_cluster_name" {
  description = "Nome lógico do cluster principal"
  type        = string
  default     = "master-engine"
}

variable "secondary_cluster_name" {
  description = "Nome lógico do segundo cluster (foco em workloads de aplicação)"
  type        = string
  default     = "app-engine"
}

variable "gke_clusters" {
  description = "Mapa com as configurações de cada cluster GKE"
  type = map(object({
    region                  = string
    zone                    = string
    initial_node_count      = number
    min_node_count          = number
    max_node_count          = number
    machine_type            = string
    disk_size_gb            = number
    enable_private_nodes    = bool
    enable_private_endpoint = bool
    master_authorized_networks = optional(list(object({
      cidr_block   = string
      display_name = string
    })), [])
  }))
  default = {
    master-engine = {
      region                     = "us-central1"
      zone                       = "us-central1-a"
      initial_node_count         = 1
      min_node_count             = 1
      max_node_count             = 6
      machine_type               = "e2-medium"
      disk_size_gb               = 50
      enable_private_nodes       = true
      enable_private_endpoint    = false
      master_authorized_networks = []
    }
    app-engine = {
      region                     = "us-east1"
      zone                       = "us-east1-b"
      initial_node_count         = 1
      min_node_count             = 1
      max_node_count             = 6
      machine_type               = "e2-medium"
      disk_size_gb               = 50
      enable_private_nodes       = true
      enable_private_endpoint    = false
      master_authorized_networks = []
    }
  }
}


variable "domain_name" {
  description = "Domínio raiz gerenciado no Cloud DNS (ex.: cloudab.online)"
  type        = string
  default     = "cloudab.online"
}

variable "enable_gke" {
  description = "Habilita ou desabilita a criação dos clusters GKE"
  type        = bool
  default     = true
}

variable "enable_asm" {
  description = "Habilita ou desabilita o Anthos Service Mesh"
  type        = bool
  default     = true
}
