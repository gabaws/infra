terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.41"
    }
  }
}

resource "google_storage_bucket" "terraform_state" {
  name          = var.bucket_name
  location      = var.bucket_location
  project       = var.project_id
  force_destroy = var.force_destroy

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = var.num_newer_versions
    }
    action {
      type = "Delete"
    }
  }

  encryption {
    default_kms_key_name = var.kms_key_name
  }

  labels = var.labels
}

resource "google_storage_bucket_iam_member" "terraform_state_admin" {
  for_each = toset(var.admins)

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = each.value
}

resource "google_storage_bucket_iam_member" "terraform_state_reader" {
  for_each = toset(var.readers)

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectViewer"
  member = each.value
}

