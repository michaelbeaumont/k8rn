output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "machine_secrets" {
  value     = talos_machine_secrets.this.machine_secrets
  sensitive = true
}


output "has_control_plane" {
  value = length(local.control_plane_nodes) > 0
}

output "kubeconfig" {
  value     = ephemeral.talos_cluster_kubeconfig.this
  sensitive = true
  ephemeral = true
}

output "talos_image" {
  value     = local.image_uri
  sensitive = false
}

output "talos_url" {
  value     = { for node, urls in data.talos_image_factory_urls.this : node => urls.urls.iso_secureboot }
  sensitive = false
}

output "nodes" {
  value     = { for node_name, node in random_uuid.nodes : node_name => node.result }
  sensitive = false
}
