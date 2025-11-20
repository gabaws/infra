terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.41"
    }
  }
}

resource "google_compute_network" "vpc" {
  count                   = var.manage_network ? 1 : 0
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  project = var.project_id
}

data "google_compute_network" "existing" {
  count   = var.manage_network ? 0 : 1
  name    = var.network_name
  project = var.project_id
}

locals {
  network_id = coalesce(
    try(google_compute_network.vpc[0].id, null),
    try(data.google_compute_network.existing[0].id, null)
  )

  network_self_link = coalesce(
    try(google_compute_network.vpc[0].self_link, null),
    try(data.google_compute_network.existing[0].self_link, null)
  )

  network_name = coalesce(
    try(google_compute_network.vpc[0].name, null),
    try(data.google_compute_network.existing[0].name, null)
  )
}

resource "google_compute_subnetwork" "subnets" {
  for_each = {
    for subnet in var.subnets : subnet.name => subnet
  }

  name          = each.value.name
  ip_cidr_range = each.value.ip_cidr_range
  region        = each.value.region
  network       = local.network_self_link
  project       = var.project_id

  description = try(each.value.description, "Subnet ${each.value.name}")

  dynamic "secondary_ip_range" {
    for_each = try(var.secondary_ranges[each.value.name], [])
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }

  private_ip_google_access = var.enable_private_google_access
}

resource "google_compute_router" "router" {
  for_each = {
    for subnet in var.subnets : subnet.region => subnet
    if var.enable_cloud_nat
  }

  name    = "router-${each.value.region}"
  region  = each.value.region
  network = local.network_self_link
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  for_each = {
    for subnet in var.subnets : subnet.region => subnet
    if var.enable_cloud_nat
  }

  name                               = "nat-${each.value.region}"
  router                             = google_compute_router.router[each.value.region].name
  region                             = each.value.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  project = var.project_id
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = local.network_name
  project = var.project_id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    for subnet in var.subnets : subnet.ip_cidr_range
  ]

  priority = 65534
}

resource "google_compute_firewall" "allow_ssh" {
  count   = var.enable_ssh ? 1 : 0
  name    = "${var.network_name}-allow-ssh"
  network = local.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["ssh"]

  priority = 1000
}

