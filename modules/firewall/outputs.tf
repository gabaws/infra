output "firewall_rules" {
  description = "IDs das regras de firewall criadas para o Service Mesh"
  value = {
    tcp = google_compute_firewall.service_mesh_ingress.id
    udp = google_compute_firewall.service_mesh_udp.id
  }
}

output "firewall_rule_names" {
  description = "Nomes das regras de firewall criadas"
  value = {
    tcp = google_compute_firewall.service_mesh_ingress.name
    udp = google_compute_firewall.service_mesh_udp.name
  }
}

