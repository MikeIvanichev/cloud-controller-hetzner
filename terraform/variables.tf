# Talos specific variables
variable "image_id" {
  type = string
}

variable "cluster_name" {
  type        = string
  description = "A name for the cluster"
}

# Control plane
variable "server_type" {
  type = string
}

variable "server_location" {
  type = string
}

variable "datacenter" {
  type = string
}

variable "node_ip" {
  default = "10.0.0.2"
  type    = string
}

# Networking
variable "private_network_name" {
  type    = string
  default = "cluster-network"
}

variable "private_network_ip_range" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_network_subnet_range" {
  type    = string
  default = "10.0.0.0/24"
}

variable "network_zone" {
  type = string
}
