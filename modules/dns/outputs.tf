output "zone_name" {
  description = "Nome da zona DNS gerenciada"
  value       = google_dns_managed_zone.public_zone.name
}

output "zone_dns_name" {
  description = "Nome DNS da zona (FQDN)"
  value       = google_dns_managed_zone.public_zone.dns_name
}

output "nameservers" {
  description = "Nameservers públicos do Cloud DNS para apontar no registrador"
  value       = google_dns_managed_zone.public_zone.name_servers
}

