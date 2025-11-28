terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.41"
    }
  }
}

# Regras de firewall para Cloud Service Mesh multi-cluster
# Estas regras permitem a descoberta de endpoints entre clusters
# Documentação: https://cloud.google.com/service-mesh/docs/operate-and-maintain/multi-cluster

locals {
  # Extrai todos os CIDRs das subnets para permitir tráfego bidirecional
  # Todas as subnets podem se comunicar entre si para suportar multi-cluster
  subnet_cidrs = [
    for subnet in var.subnets : subnet.ip_cidr_range
  ]
}

# Regra de firewall global para permitir tráfego do Service Mesh entre todos os clusters
# Esta regra permite comunicação entre os sidecars Envoy, Istiod e health checks
# Documentação: https://cloud.google.com/service-mesh/docs/operate-and-maintain/multi-cluster
resource "google_compute_firewall" "service_mesh_ingress" {
  name    = "${var.network_name}-allow-service-mesh-tcp"
  network = var.network_name
  project = var.project_id

  description = "Permite tráfego TCP do Cloud Service Mesh para descoberta de endpoints entre clusters. Permite comunicação bidirecional entre todos os clusters na malha."

  # Portas necessárias para o Cloud Service Mesh / Istio:
  # - 15012: Istiod - distribuição de certificados mTLS entre clusters
  # - 15017: Istiod - webhook de validação de configuração
  # - 443: Tráfego mTLS Envoy cross-cluster (HTTPS seguro)
  # - 10250: Kubelet internode - health checks e liveness probes
  # - 15010: Envoy ↔ Envoy - xDS e controle (dependendo da versão)
  # - 15011: Envoy ↔ Envoy - xDS e controle (dependendo da versão)
  allow {
    protocol = "tcp"
    ports    = ["15012", "15017", "443", "10250", "15010", "15011"]
  }

  # Permite ICMP para troubleshooting de conectividade de rede
  allow {
    protocol = "icmp"
  }

  # Origem: todas as subnets dos clusters (incluindo a própria)
  # Isso permite comunicação bidirecional entre todos os clusters na mesma VPC
  # Cada subnet pode se comunicar com todas as outras subnets
  source_ranges = local.subnet_cidrs

  # Não especificamos target_tags para aplicar a todos os nodes na rede
  # Como os clusters estão em subnets diferentes, o tráfego já é filtrado por subnet
  # Se necessário, você pode adicionar target_tags específicos por cluster

  # Prioridade alta para garantir que estas regras sejam aplicadas antes de regras mais restritivas
  priority = 1000

  # Logs de firewall habilitados para troubleshooting
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Regra adicional para permitir tráfego UDP necessário para alguns componentes
# (DNS, telemetria, etc.)
resource "google_compute_firewall" "service_mesh_udp" {
  name    = "${var.network_name}-allow-service-mesh-udp"
  network = var.network_name
  project = var.project_id

  description = "Permite tráfego UDP do Cloud Service Mesh para telemetria, DNS e métricas entre clusters."

  allow {
    protocol = "udp"
    # - 53: DNS interno do Kubernetes
    # - 8125: StatsD (telemetria)
    # - 8126: StatsD (telemetria)
    ports = ["53", "8125", "8126"]
  }

  source_ranges = local.subnet_cidrs

  priority = 1000

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

