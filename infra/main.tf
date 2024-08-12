terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.6.0-alpha.1"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.16.1"
    }
    external = {
      source  = "external"
      version = "2.3.1"
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
      version = "~> 4.0"
    }
  }
}

variable "talos_version" {
  description = "Version of everything talos to use"
  type        = string
}

variable "github_repo" {
  description = "The github organization/repo where this repository is reachable"
  type        = string
}

variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
}

variable "control_plane_nodes" {
  description = "The local IPs and tailscale IPs of the control plane nodes"
  type        = list(object({ local_ip = string, tailscale_ip = string }))
}

variable "node_ip_kind" {
  description = "Whether to use local or tailscale to contact nodes"
  type        = string
  default     = "local_ip"

  validation {
    condition     = contains(["local_ip", "tailscale_ip"], var.node_ip_kind)
    error_message = "You must select either local_ip or tailscale_ip"
  }
}

variable "dns_loadbalancer_domain" {
  description = "Domain used for DNS load balancing the nodes"
  type        = string
}

variable "kms_endpoint" {
  description = "Endpoint for the Talos KMS service"
  type        = string
}

variable "external_server_hostname" {
  description = "Tailscale hostname for external server where some services still run"
  type        = string
}

variable "tailnet_oauth_client_id" {
  description = "OAuth client ID for creating tailnet key"
  type        = string
}
variable "tailnet_oauth_client_secret" {
  description = "OAuth client secret for creating tailnet key"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain"
  type        = string
}
variable "cloudflare_token" {
  description = "Token for Cloudflare API"
  type        = string
}

variable "mayastor_io_engine_nodes" {
  description = "The local IPs of nodes that should be marked for mayastor io-engine"
  type        = list(string)
}

// port must match localAPIServerPort
locals {
  hostnames = merge({
    for num, node in var.control_plane_nodes :
    node.local_ip => "k8rn-cp-${num}"
    }, {
    for num, node in var.control_plane_nodes :
    node.tailscale_ip => "k8rn-cp-${num}"
  })
  ips = {
    for num, node in var.control_plane_nodes :
    local.hostnames[node.local_ip] => node
  }
  dns_loadbalancer_hostname = "${var.cluster_name}.${var.dns_loadbalancer_domain}"
  cluster_endpoint          = "https://${local.dns_loadbalancer_hostname}:6443"
}

variable "flux_ssh_private_key" {
  type = string
}

variable "flux_sops_age_key" {
  type = string
}
