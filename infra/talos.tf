data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for node in var.control_plane_nodes : node.tailscale_ip]
  endpoints            = [local.dns_loadbalancer_hostname]
}

resource "talos_machine_bootstrap" "first_control_plane_node" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = talos_machine_configuration_apply.this[var.control_plane_nodes[0].local_ip].node
}

resource "talos_machine_configuration_apply" "this" {
  for_each                    = toset([for node in var.control_plane_nodes : node.local_ip])
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.value].machine_configuration
  node                        = each.value
}

data "talos_cluster_health" "this" {
  client_configuration   = talos_machine_secrets.this.client_configuration
  control_plane_nodes    = [for key, _ in talos_machine_configuration_apply.this : local.ips[local.hostnames[key]].tailscale_ip]
  skip_kubernetes_checks = true
  endpoints              = [local.dns_loadbalancer_hostname]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.talos_cluster_health.this.control_plane_nodes[0]
}
