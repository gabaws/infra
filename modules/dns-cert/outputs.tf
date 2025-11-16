output "nameservers" {
  description = "Nameservers públicos do Cloud DNS para apontar no registrador"
  value       = google_dns_managed_zone.public_zone.name_servers
}

output "certificate_name" {
  description = "Nome do certificado gerenciado (Certificate Manager)"
  value       = google_certificate_manager_certificate.wildcard.name
}

output "certificate_self_link" {
  description = "Self-link do certificado gerenciado"
  value       = google_certificate_manager_certificate.wildcard.self_link
}


