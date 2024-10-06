terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.6.0-alpha.1"
    }
  }
}


# Set the variable value in *.tfvars file
# or using the -var="hcloud_token=..." CLI option
variable "hcloud_token" {
  type      = string
  sensitive = true
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

# NETWORKING
resource "hcloud_network" "network" {
  name     = var.private_network_name
  ip_range = var.private_network_ip_range
}

resource "hcloud_network_subnet" "subnet" {
  network_id   = hcloud_network.network.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.private_network_subnet_range
}

resource "hcloud_primary_ip" "ipv4_address" {
  name          = "core-ipv4"
  datacenter    = var.datacenter
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false # all state is managed by tf
}

resource "hcloud_primary_ip" "ipv6_address" {
  name          = "core-ipv6"
  datacenter    = var.datacenter
  type          = "ipv6"
  assignee_type = "server"
  auto_delete   = false # all state is managed by tf
}

# Talos
# create the machine secrets
resource "talos_machine_secrets" "this" {}

# create the controlplane config, using the loadbalancer as cluster endpoint
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${hcloud_primary_ip.ipv4_address.ip_address}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    templatefile("${path.module}/templates/node.yaml.tmpl", {
      publicip = hcloud_primary_ip.ipv4_address.ip_address, subnet = var.private_network_subnet_range
    })
  ]
  depends_on = [
    hcloud_primary_ip.ipv4_address
  ]
}

# create the talos client config
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [
    hcloud_primary_ip.ipv4_address.ip_address
  ]
}

# create the control plane and apply generated config in user_data
resource "hcloud_server" "controlplane_server" {
  name        = "core-controlplane"
  image       = var.image_id
  server_type = var.server_type
  location    = var.server_location
  labels      = { type = "talos-controlplane" }
  user_data   = data.talos_machine_configuration.controlplane.machine_configuration
  network {
    network_id = hcloud_network.network.id
    ip         = var.node_ip
  }
  public_net {
    ipv4 = hcloud_primary_ip.ipv4_address.id
    ipv6 = hcloud_primary_ip.ipv6_address.id
  }
  depends_on = [
    hcloud_network_subnet.subnet,
    hcloud_primary_ip.ipv4_address,
    hcloud_primary_ip.ipv6_address,
    talos_machine_secrets.this,
  ]
}

# bootstrap the cluster
resource "talos_machine_bootstrap" "bootstrap" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = hcloud_server.controlplane_server.ipv4_address
  node                 = hcloud_server.controlplane_server.ipv4_address
}

# kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.controlplane_server.ipv4_address
}
