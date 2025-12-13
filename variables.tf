variable "github_repo" {
  description = "The github organization/repo where this repository is reachable"
  type        = string
}

variable "talos_version" {
  description = "Version of everything talos to use"
  type        = string
}

variable "nodes" {
  description = "A description of all nodes, used to generate initial images"
  type        = map(object({ local_ip = string, disk_selector = map(any), kernel_args = optional(list(string), []), network_devices = list(string), tags = list(string) }))
}

variable "bootstrap_node" {
  description = "The node to bootstrap from"
  type        = string
}

variable "mayastor_io_engine_nodes" {
  description = "The local IPs of nodes that should be marked for mayastor io-engine"
  type        = list(string)
}

variable "kms_endpoint" {
  description = "Endpoint for the Talos KMS service"
  type        = string
}

variable "stable_secret" {
  description = "IPv6 stable secret for RFC7217"
  type        = string
}

variable "dns_loadbalancer_domain" {
  description = "Domain used for DNS load balancing the nodes"
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

variable "cluster_oidc_issuer_host" {
  description = "The issuer hostname to use for cluster OIDC authentication"
  type        = string
}

variable "cluster_oidc_client_id" {
  description = "The client ID to use for cluster OIDC authentication"
  type        = string
}

variable "cloudflare_zone" {
  description = "Name of the cloudflare zone"
  type        = string
}

variable "cloudflare_token" {
  description = "Token for Cloudflare API"
  type        = string
}

variable "tailnet_name" {
  description = "Name of the tailnet"
  type        = string
}

variable "flux_ssh_private_key" {
  description = "Key used by Flux to access the repo"
  type        = string
}

variable "flux_sops_age_key" {
  description = "Key used by Flux to decrypt SOPS-encrypted resources"
  type        = string
}

variable "restic_remote_password" {
  description = "Password for remote restic repo"
  type        = string
  sensitive   = true
}

variable "lets_encrypt_email" {
  description = "Email to use for Lets Encrypt certs"
  type        = string
}

variable "services_hostname_suffix" {
  description = "Domain suffix common to all services gateway routes"
  type        = string
}
