terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.41"
    }
  }
}

resource "google_certificate_manager_dns_authorization" "auth_root" {
  name        = "auth-${replace(var.domain_name, ".", "-")}"
  domain      = var.domain_name
  description = "Autorização DNS para ${var.domain_name} e *.${var.domain_name}"
}

resource "google_dns_record_set" "auth_record" {
  name         = google_certificate_manager_dns_authorization.auth_root.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.auth_root.dns_resource_record[0].type
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = [google_certificate_manager_dns_authorization.auth_root.dns_resource_record[0].data]
}

resource "google_certificate_manager_certificate" "wildcard" {
  name        = "wildcard-${replace(var.domain_name, ".", "-")}"
  description = "Certificado gerenciado para *.${var.domain_name} e ${var.domain_name}"
  project     = var.project_id

  managed {
    domains = [
      var.domain_name,
      "*.${var.domain_name}",
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.auth_root.id,
    ]
  }

  depends_on = [
    google_dns_record_set.auth_record
  ]
}

resource "google_certificate_manager_certificate_map" "wildcard_map" {
  name        = "wildcard-${replace(var.domain_name, ".", "-")}-map"
  description = "Certificate Map para ${var.domain_name} e *.${var.domain_name}"
  project     = var.project_id
}

resource "google_certificate_manager_certificate_map_entry" "wildcard_entry" {
  name         = "wildcard-${replace(var.domain_name, ".", "-")}-entry"
  description  = "Entrada do certificado coringa no map"
  map          = google_certificate_manager_certificate_map.wildcard_map.name
  certificates = [google_certificate_manager_certificate.wildcard.id]
  hostname     = "*.${var.domain_name}"
  project      = var.project_id
}

resource "google_certificate_manager_certificate_map_entry" "apex_entry" {
  name         = "apex-${replace(var.domain_name, ".", "-")}-entry"
  description  = "Entrada do certificado para o domínio raiz"
  map          = google_certificate_manager_certificate_map.wildcard_map.name
  certificates = [google_certificate_manager_certificate.wildcard.id]
  hostname     = var.domain_name
  project      = var.project_id
}

