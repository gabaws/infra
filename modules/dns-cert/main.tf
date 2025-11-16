terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.41"
    }
  }
}

provider "google" {
  project = var.project_id
}

# Zona pública do Cloud DNS
resource "google_dns_managed_zone" "public_zone" {
  name        = "public-zone-${replace(var.domain_name, ".", "-")}"
  dns_name    = "${var.domain_name}."
  description = "Zona pública para ${var.domain_name}"
  visibility  = "public"
}

# Autorização DNS para Certificate Manager (usada na emissão do certificado)
resource "google_certificate_manager_dns_authorization" "auth_root" {
  name        = "auth-${replace(var.domain_name, ".", "-")}"
  domain      = var.domain_name
  description = "Autorização DNS para ${var.domain_name}"
}

# Registro TXT de verificação do DNS Authorization
resource "google_dns_record_set" "auth_txt" {
  name         = google_certificate_manager_dns_authorization.auth_root.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.auth_root.dns_resource_record[0].type
  ttl          = 300
  managed_zone = google_dns_managed_zone.public_zone.name
  rrdatas      = [google_certificate_manager_dns_authorization.auth_root.dns_resource_record[0].data]
}

# Certificado gerenciado coringa (apex + wildcard)
resource "google_certificate_manager_certificate" "wildcard" {
  name        = "wildcard-${replace(var.domain_name, ".", "-")}"
  description = "Certificado gerenciado para *.${var.domain_name} e ${var.domain_name}"

  managed {
    domains = [
      var.domain_name,
      "*.${var.domain_name}",
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.auth_root.id,
    ]
  }

  depends_on = [google_dns_record_set.auth_txt]
}


