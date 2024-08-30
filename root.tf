terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.16.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.31.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "tailscale" {
  oauth_client_id     = var.tailnet_oauth_client_id
  oauth_client_secret = var.tailnet_oauth_client_secret
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

module "infra" {
  source = "./infra"

  talos_version = var.talos_version
  cluster_name  = "k8rn"

  control_plane_nodes      = var.control_plane_nodes
  bootstrap_node           = var.bootstrap_node
  worker_nodes             = var.worker_nodes
  tailnet_name             = var.tailnet_name
  mayastor_io_engine_nodes = var.mayastor_io_engine_nodes
  stable_secret            = var.stable_secret
  pod_subnets = [
    // "fdd2:14fe:fb0::/52", // randomly generated, TODO: ipv6 mayastor
    "10.244.0.0/16",
  ]
  service_subnets = [
    // "fdd2:14fe:fb0:1000::/108", // randomly generated, TODO: ipv6 mayastor
    "10.96.0.0/12",
  ]
  dns_loadbalancer_domain = var.dns_loadbalancer_domain
  kms_endpoint            = var.kms_endpoint
  cloudflare_zone         = var.cloudflare_zone
}

locals {
  k8s_config = length(module.infra.kubeconfig) != 0 ? {
    host                   = module.infra.kubeconfig.0.kubernetes_client_configuration.host
    client_certificate     = base64decode(module.infra.kubeconfig.0.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(module.infra.kubeconfig.0.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(module.infra.kubeconfig.0.kubernetes_client_configuration.ca_certificate)
    raw                    = module.infra.kubeconfig.0.kubeconfig_raw
    } : {
    host                   = null
    client_certificate     = null
    client_key             = null
    cluster_ca_certificate = null
    raw                    = null
  }
}

provider "kubernetes" {
  host                   = local.k8s_config.host
  client_certificate     = local.k8s_config.client_certificate
  client_key             = local.k8s_config.client_key
  cluster_ca_certificate = local.k8s_config.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_config.host
    client_certificate     = local.k8s_config.client_certificate
    client_key             = local.k8s_config.client_key
    cluster_ca_certificate = local.k8s_config.cluster_ca_certificate
  }
}

module "k8s" {
  source = "./k8s"

  count = length(module.infra.kubeconfig) > 0 ? 1 : 0

  github_repo               = var.github_repo
  lets_encrypt_email        = var.lets_encrypt_email
  services_hostname_suffix  = var.services_hostname_suffix
  flux_ssh_private_key      = var.flux_ssh_private_key
  flux_sops_age_key         = var.flux_sops_age_key
  external_server_hostname  = var.external_server_hostname
}

output "talosconfig" {
  value     = module.infra.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = local.k8s_config.raw
  sensitive = true
}

output "machine_secrets" {
  value     = yamlencode(module.infra.machine_secrets)
  sensitive = true
}

output "talos_url" {
  value     = module.infra.talos_url
  sensitive = false
}

output "talos_image" {
  value     = module.infra.talos_image
  sensitive = false
}
