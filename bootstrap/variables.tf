variable "bootstrap_project_id" {
  description = "Project ID where the state bucket will be created"
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

