terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.31.0"
    }
    corefunc = {
      source  = "northwood-labs/corefunc"
      version = "~> 2.0"
    }
  }
}

variable "flux_ssh_private_key" {
  type = string
}

variable "flux_sops_age_key" {
  type = string
}

variable "openebs_etcd_replicaCount" {
  description = "How many replicas OpenEBS's etcd storage should use"
  type        = number
}

variable "openebs_diskpool_partition_label" {
  description = "Label for OpenEBS DiskPool partitions"
  type        = string
}

variable "restic_remote_password" {
  description = "Password for remote restic repo"
  type        = string
  sensitive   = true
}

variable "local_cidr" {
  description = "Local subnets"
  type        = object({ ipv4 = string, ipv6 = string })
}

variable "pod_cidr" {
  description = "Pod subnets"
  type        = object({ ipv4 = string, ipv6 = string })
}

variable "node_labels" {
  description = "Nodes"
  type        = map(map(string))
}

variable "node_taints" {
  description = "Nodes"
  type        = map(map(string))
}

variable "kms_endpoint" {
  type = string
}

output "flux_ssh_public_key" {
  description = "Public SSH key Flux uses to access Git repositories"
  value       = data.tls_public_key.flux_ssh.public_key_openssh
}

