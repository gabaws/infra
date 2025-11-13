variable "project_id" {
  description = "The GCP project ID where the bucket will be created"
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

variable "force_destroy" {
  description = "When deleting a bucket, this boolean option will delete all contained objects"
  type        = bool
  default     = false
}

variable "num_newer_versions" {
  description = "Number of versions to keep for state files"
  type        = number
  default     = 5
}

variable "kms_key_name" {
  description = "KMS key name for bucket encryption (optional)"
  type        = string
  default     = null
}

variable "admins" {
  description = "List of IAM members with admin access to the bucket"
  type        = list(string)
  default     = []
}

variable "readers" {
  description = "List of IAM members with read access to the bucket"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels to apply to the bucket"
  type        = map(string)
  default = {
    managed-by = "terraform"
    purpose    = "terraform-state"
  }
}

