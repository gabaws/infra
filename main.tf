terraform {
    require_providers {
        google = {
            source = "hashicorp/google"
            version = "~> 6.0"
        }
    }
    require_version = ">=1.6.0"
}

provider "google" {
    project = var.project_id
    region = var.region
}

resource "google_storage_bucket" "infra" {
    name = "infra-bucket"-${var.project_id}
    location = "US"
}