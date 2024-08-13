data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for node in var.control_plane_nodes : node.tailscale_ip]
  endpoints            = [local.dns_loadbalancer_hostname]
}

resource "talos_machine_bootstrap" "first_control_plane_node" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node = [
    for node in var.control_plane_nodes
    : node.tailscale_ip
    if talos_machine_configuration_apply.control_plane[var.bootstrap_node].node == node.local_ip
    || talos_machine_configuration_apply.control_plane[var.bootstrap_node].node == node.tailscale_ip
  ][0]
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each                    = var.control_plane_nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane_nodes[each.key].machine_configuration
  node                        = lookup(each.value, var.node_ip_kind)
}

resource "talos_machine_configuration_apply" "workers" {
  for_each                    = var.worker_nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker_nodes[each.key].machine_configuration
  node                        = lookup(each.value, var.node_ip_kind)
  endpoint                    = local.dns_loadbalancer_hostname
}

data "talos_cluster_health" "this" {
  client_configuration   = talos_machine_secrets.this.client_configuration
  control_plane_nodes    = [for key, _ in talos_machine_configuration_apply.control_plane : var.control_plane_nodes[key].tailscale_ip]
  worker_nodes           = [for key, _ in talos_machine_configuration_apply.workers : var.worker_nodes[key].tailscale_ip]
  skip_kubernetes_checks = true
  endpoints              = [local.dns_loadbalancer_hostname]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node = [
    for ip in data.talos_cluster_health.this.control_plane_nodes :
    ip if var.control_plane_nodes[var.bootstrap_node].tailscale_ip == ip
  ][0]
}
