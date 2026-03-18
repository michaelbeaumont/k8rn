output "talosconfig" {
  description = "Use with talosctl"
  value       = module.infra.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Use with kubectl"
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Config",
    clusters = [{
      name = local.cluster_name,
      cluster = {
        certificate-authority-data = module.infra.machine_secrets.certs.k8s.cert,
        server                     = "https://${local.cluster_name}.${var.dns_loadbalancer_domain}:6443",
      },
    }],
    contexts = [{
      context = {
        cluster = local.cluster_name,
        user    = var.cluster_oidc_issuer_host,
      },
      name = local.cluster_name,
    }],
    current-context = local.cluster_name,
    users = [{
      name = var.cluster_oidc_issuer_host,
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1"
          command    = "kubectl",
          args = [
            "oidc-login",
            "get-token",
            "--oidc-issuer-url=https://${var.cluster_oidc_issuer_host}",
            "--oidc-client-id=${var.cluster_oidc_client_id}",
            "--oidc-extra-scope=profile",
            "--oidc-extra-scope=groups",
            "--oidc-pkce-method=S256",
          ],
          interactiveMode    = "Never",
          provideClusterInfo = false,
        },
      },
    }],
  })
  sensitive = true
}

output "machine_secrets" {
  description = "Full access to the cluster if the state is lost"
  value       = yamlencode(module.infra.machine_secrets)
  sensitive   = true
}

output "flux_ssh_public_key" {
  description = "Public SSH key Flux uses to access Git repositories"
  value       = module.k8s[0].flux_ssh_public_key
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

output "talos_image_cache" {
  description = "Image path segment to use for upgrade images if running off the local cahe"
  value = {
    for node, image in module.infra.talos_image : node => provider::corefunc::url_parse("https://${image}").path
  }
  sensitive = false
}

output "nodes" {
  description = "Nodes and their UUIDs"
  value       = module.infra.nodes
  sensitive   = false
}

output "image_cache_serve_cert" {
  value     = module.infra.image_cache_serve_cert
  sensitive = true
}
