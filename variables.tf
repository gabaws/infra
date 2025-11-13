variable "project_id" {
  description = "The GCP project ID to use (existing project)"
  type        = string
  default     = "infra-474223"
}

variable "region" {
  description = "The default region for resources"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "main-vpc"
}

variable "manage_network" {
  description = "When false, reuse an existing VPC network instead of creating it"
  type        = bool
  default     = true
}

variable "subnets" {
  description = "List of subnets to create"
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
      description   = "Subnet for us-central1 region"
    },
    {
      name          = "subnet-us-east1"
      ip_cidr_range = "10.0.2.0/24"
      region        = "us-east1"
      description   = "Subnet for us-east1 region"
    }
  ]
}

variable "secondary_ranges" {
  description = "Secondary IP ranges for GKE pods and services"
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

variable "gke_clusters" {
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
    master_authorized_networks = optional(list(object({
      cidr_block   = string
      display_name = string
    })), [])
  }))
  default = {
    cluster-1 = {
      region                     = "us-central1"
      zone                       = "us-central1-a"
      initial_node_count         = 1
      min_node_count             = 1
      max_node_count             = 5
      machine_type               = "e2-medium"
      disk_size_gb               = 50
      enable_private_nodes       = true
      enable_private_endpoint    = false
      master_authorized_networks = []
    }
    cluster-2 = {
      region                     = "us-east1"
      zone                       = "us-east1-b"
      initial_node_count         = 1
      min_node_count             = 1
      max_node_count             = 5
      machine_type               = "e2-medium"
      disk_size_gb               = 50
      enable_private_nodes       = true
      enable_private_endpoint    = false
      master_authorized_networks = []
    }
  }
}

