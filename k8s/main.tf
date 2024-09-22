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

variable "nfs_server" {
  description = "NFS server endpoint"
  type        = string
}

variable "openebs_etcd_replicaCount" {
  description = "How many replicas OpenEBS's etcd storage should use"
  type        = number
}

variable "restic_remote_password" {
  description = "Password for remote restic repo"
  type        = string
  sensitive   = true
}

variable "add_data_partition_nodes" {
  description = "Nodes to run add partition job on"
  type        = set(string)
}

variable "nodes" {
  description = "Nodes"
  type        = set(string)
}

variable "local_cidr" {
  description = "Local subnets"
  type        = object({ ipv4 = string, ipv6 = string })
}

variable "pod_cidr" {
  description = "Pod subnets"
  type        = object({ ipv4 = string, ipv6 = string })
}
