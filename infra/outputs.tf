output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "machine_secrets" {
  value     = talos_machine_secrets.this.machine_secrets
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talos_installer_uri" {
  value     = local.talos_installer_uri
  sensitive = false
}
