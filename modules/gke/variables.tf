variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The default region for resources"
  type        = string
}

variable "network" {
  description = "The VPC network name"
  type        = string
}

variable "subnets" {
  description = "Map of subnets with their configurations"
  type = map(object({
    name          = string
    ip_cidr_range = string
    region        = string
    self_link     = string
    secondary_ip_ranges = list(object({
      range_name    = string
      ip_cidr_range = string
    }))
  }))
}

variable "clusters" {
  description = "Configuration for GKE clusters"
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
    master_ipv4_cidr_block  = optional(string)
    master_authorized_networks = optional(list(object({
      cidr_block   = string
      display_name = string
    })), [])
    service_account = optional(string)
    preemptible     = optional(bool)
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
}

