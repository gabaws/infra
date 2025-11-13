# Bootstrap script para criar o bucket do estado do Terraform
# Execute este módulo ANTES de usar o backend remoto
# Uso: terraform apply -target=module.bootstrap

terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.41"
    }
  }
}

provider "google" {
  # Use suas credenciais locais ou variáveis de ambiente
  # project = var.bootstrap_project_id
  # region  = var.region
}

variable "bootstrap_project_id" {
  description = "Project ID where the state bucket will be created (can be a different project)"
  type        = string
}

variable "bucket_name" {
  description = "Name of the GCS bucket for Terraform state"
  type        = string
}

variable "bucket_location" {
  description = "Location of the GCS bucket"
  type        = string
  default     = "US"
}

variable "region" {
  description = "Default region"
  type        = string
  default     = "us-central1"
}

module "terraform_backend" {
  source = "../modules/terraform-backend"

  project_id         = var.bootstrap_project_id
  bucket_name        = var.bucket_name
  bucket_location    = var.bucket_location
  force_destroy      = false
  num_newer_versions = 5

  labels = {
    managed-by = "terraform"
    purpose    = "terraform-state"
  }
}

output "bucket_name" {
  description = "Name of the created bucket"
  value       = module.terraform_backend.bucket_name
}

output "backend_config" {
  description = "Backend configuration to add to versions.tf"
  value       = <<-EOT
    backend "gcs" {
      bucket = "${module.terraform_backend.bucket_name}"
      prefix = "terraform/state"
    }
  EOT
}

