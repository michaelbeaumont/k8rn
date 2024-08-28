output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "machine_secrets" {
  value     = talos_machine_secrets.this.machine_secrets
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this
  sensitive = true
}

output "talos_image" {
  value     = local.image_uri
  sensitive = false
}

output "talos_url" {
  value     = data.talos_image_factory_urls.this.urls.iso_secureboot
  sensitive = false
}
