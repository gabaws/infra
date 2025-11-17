output "certificate_name" {
  description = "Nome do certificado gerenciado (Certificate Manager)"
  value       = google_certificate_manager_certificate.wildcard.name
}

output "certificate_id" {
  description = "ID completo do certificado gerenciado"
  value       = google_certificate_manager_certificate.wildcard.id
}

output "certificate_map_name" {
  description = "Nome do Certificate Map para uso no GKE Managed Gateway API"
  value       = google_certificate_manager_certificate_map.wildcard_map.name
}

output "certificate_map_id" {
  description = "ID completo do Certificate Map (projects/PROJECT/locations/global/certificateMaps/NAME)"
  value       = google_certificate_manager_certificate_map.wildcard_map.id
}

