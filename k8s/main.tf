terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">=0.16.1"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">=1.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.31.0"
    }
  }
}

variable "flux_ssh_private_key" {
  type = string
}

variable "flux_sops_age_key" {
  type = string
}

variable "external_server_hostname" {
  description = "Tailscale hostname for external server where some services still run"
  type        = string
}
