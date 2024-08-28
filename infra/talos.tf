data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes = concat(
    [for dev in data.tailscale_device.cp : dev.hostname],
    [for dev in data.tailscale_device.worker : dev.addresses[1]], // TODO: hostname should work once tailscale DNS works in-node
  )
  endpoints = [local.dns_loadbalancer_hostname]
}

resource "talos_machine_bootstrap" "first_control_plane_node" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.tailscale_device.cp[var.bootstrap_node].addresses[1]
}

// The init/post_init split allows us to apply an initial config using the local
// IP with _iniy but from then on never try to use the local IP, instead using _post_init
// which applies using the tailscale IP
resource "talos_machine_configuration_apply" "control_plane_init" {
  for_each                    = var.control_plane_nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane_nodes[each.key].machine_configuration
  node                        = each.value.local_ip
  lifecycle {
    ignore_changes = [
      machine_configuration_input,
    ]
  }
  apply_mode = "reboot"
}

resource "talos_machine_configuration_apply" "control_plane_post_init" {
  for_each                    = talos_machine_configuration_apply.control_plane_init
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane_nodes[each.key].machine_configuration
  node                        = cloudflare_record.cp_aaaa[each.key].content
  endpoint                    = local.dns_loadbalancer_hostname
}

resource "talos_machine_configuration_apply" "workers_init" {
  for_each                    = var.worker_nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker_nodes[each.key].machine_configuration
  node                        = each.value.local_ip
  lifecycle {
    ignore_changes = [
      machine_configuration_input,
    ]
  }
  apply_mode = "reboot"
}

resource "talos_machine_configuration_apply" "workers_post_init" {
  for_each                    = talos_machine_configuration_apply.workers_init
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker_nodes[each.key].machine_configuration
  node                        = data.tailscale_device.worker[each.key].addresses[1]
  endpoint                    = local.dns_loadbalancer_hostname
}

data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes = flatten([
    for name, apply in talos_machine_configuration_apply.control_plane_post_init
    : [apply.node] // [data.tailscale_device.cp[name].addresses[0], apply.node]
  ])
  worker_nodes = flatten([
    for name, apply in talos_machine_configuration_apply.workers_post_init
    : [apply.node] // [data.tailscale_device.worker[name].addresses[0], apply.node]
  ])
  skip_kubernetes_checks = true
  endpoints              = [local.dns_loadbalancer_hostname]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.talos_cluster_health.this.control_plane_nodes[0] // TODO after health [1] -> ipv6 of first node
}
