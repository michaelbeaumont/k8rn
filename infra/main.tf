terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.8.1"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">=0.16.1"
    }
    external = {
      source  = "external"
      version = ">=2.3.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.31.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">=1.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

variable "talos_version" {
  description = "Version of everything talos to use"
  type        = string
}

variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
}

variable "cluster_oidc_issuer_host" {
  description = "The issuer hostname to use for cluster OIDC authentication"
  type        = string
}

variable "cluster_oidc_client_id" {
  description = "The client ID to use for cluster OIDC authentication"
  type        = string
}

variable "nodes" {
  description = "A description of all nodes, used to generate initial images"
  type        = map(object({ local_ip = string, install_disk = optional(string), network_devices = list(string), tags = list(string) }))
}

variable "bootstrap_node" {
  description = "The node to bootstrap from"
  type        = string
}

variable "stable_secret" {
  description = "IPv6 stable secret for RFC7217"
  type        = string
}

variable "pod_subnets" {
  description = "Subnets for Pods"
  type        = list(string)
}

variable "service_subnets" {
  description = "Subnets for Services (IPv6 mask must be >= 108"
  type        = list(string)
}

variable "dns_loadbalancer_domain" {
  description = "Domain used for DNS load balancing the nodes"
  type        = string
}

variable "kms_endpoint" {
  description = "Endpoint for the Talos KMS service"
  type        = string
}

variable "cloudflare_zone" {
  description = "Cloudflare zone name"
  type        = string
}

variable "tailnet_name" {
  description = "Name of the tailnet"
  type        = string
}

variable "mayastor_io_engine_nodes" {
  description = "The local IPs of nodes that should be marked for mayastor io-engine"
  type        = list(string)
}

variable "openebs_diskpool_volume_name" {
  description = "Name of Talos RawVolumeConfig for OpenEBS DiskPool partitions"
  type        = string
}

// port must match localAPIServerPort
locals {
  hostnames = merge({
    for id, node in var.nodes :
    node.local_ip => "${id}"
    }, {
    for id, node in var.nodes :
    id => id
  })
  dns_loadbalancer_hostname = "${var.cluster_name}.${var.dns_loadbalancer_domain}"
  cluster_endpoint          = "https://${local.dns_loadbalancer_hostname}:6443"
}

locals {
  control_plane_nodes = {
    for name, node in var.nodes :
    name => node if contains(node.tags, "control_plane")
  }
  worker_nodes = {
    for name, node in var.nodes :
    name => node if contains(node.tags, "worker")
  }
}
