output "talosconfig" {
  description = "Use with talosctl"
  value       = module.infra.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Use with kubectl"
  value       = local.k8s_config.raw
  sensitive   = true
}

output "machine_secrets" {
  description = "Full access to the cluster if the state is lost"
  value       = yamlencode(module.infra.machine_secrets)
  sensitive   = true
}

output "talos_url" {
  description = "URLs to download ISO per node"
  value       = module.infra.talos_url
  sensitive   = false
}

output "talos_image" {
  description = "URLs to use for upgrade images"
  value       = module.infra.talos_image
  sensitive   = false
}

output "cluster_oidc_issuer_host" {
  description = "OIDC issuer hostname for cluster access"
  value       = var.cluster_oidc_issuer_host
}

output "cluster_oidc_client_id" {
  description = "OIDC client ID for cluster access"
  value       = var.cluster_oidc_client_id
}
