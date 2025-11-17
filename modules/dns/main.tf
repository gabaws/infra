terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.41"
    }
  }
}

# Zona pública do Cloud DNS
resource "google_dns_managed_zone" "public_zone" {
  name        = "public-zone-${replace(var.domain_name, ".", "-")}"
  dns_name    = "${var.domain_name}."
  description = "Zona pública para ${var.domain_name}"
  visibility  = "public"
}

