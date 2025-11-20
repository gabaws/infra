output "bucket_name" {
  description = "Nome do bucket GCS"
  value       = google_storage_bucket.terraform_state.name
}

output "bucket_url" {
  description = "URL do bucket GCS"
  value       = google_storage_bucket.terraform_state.url
}

output "bucket_self_link" {
  description = "Auto-vinculação do bucket GCS"
  value       = google_storage_bucket.terraform_state.self_link
}

