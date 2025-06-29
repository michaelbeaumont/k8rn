data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes = concat(
    [for dev in merge(data.tailscale_device.cp, data.tailscale_device.worker) : dev.hostname],
  )
  endpoints = [local.dns_loadbalancer_hostname]
}

resource "talos_machine_bootstrap" "this" {
  for_each             = toset([for node in keys(local.control_plane_nodes) : node if node == var.bootstrap_node])
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.tailscale_device.cp[each.key].addresses[1]
}

// The init/post_init split allows us to apply an initial config using the local
// IP with _iniy but from then on never try to use the local IP, instead using _post_init
// which applies using the tailscale IP
resource "talos_machine_configuration_apply" "control_plane_init" {
  for_each                    = local.control_plane_nodes
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
  node                        = cloudflare_dns_record.cp_aaaa[each.key].content
  endpoint                    = local.dns_loadbalancer_hostname
}

locals {
  extra_hosts_patch = templatefile(
    "${path.module}/files/extra-hosts.yaml.tmpl",
    {
      extra_hosts = [
        for dev in merge(data.tailscale_device.cp, data.tailscale_device.worker)
        : { ip = dev.addresses[1], aliases = [dev.hostname] }
      ],
    }
  )
}

// This has to be separate from post_init because this depends on workers_init
// which depends on control_plane_post_init.
resource "talos_machine_configuration_apply" "control_plane_extra_hosts" {
  for_each                    = talos_machine_configuration_apply.control_plane_post_init
  client_configuration        = each.value.client_configuration
  machine_configuration_input = each.value.machine_configuration
  node                        = each.value.node
  endpoint                    = each.value.endpoint
  config_patches = [
    local.extra_hosts_patch,
  ]
}

resource "talos_machine_configuration_apply" "workers_init" {
  for_each = local.worker_nodes
  client_configuration = [
    for _, apply in talos_machine_configuration_apply.control_plane_post_init
    : apply.client_configuration
  ][0]
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
  config_patches = [
    local.extra_hosts_patch,
  ]
}

data "talos_cluster_health" "this" {
  count                = length(local.control_plane_nodes) > 0 ? 1 : 0
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes = flatten([
    for name, apply in talos_machine_configuration_apply.control_plane_post_init
    # TODO after health is fixed use both IPs
    : [data.tailscale_device.cp[name].addresses[1]] // , data.tailscale_device.cp[name].addresses[0]]
  ])
  worker_nodes = flatten([
    for name, apply in talos_machine_configuration_apply.workers_post_init
    # TODO after health is fixed use both IPs
    : [data.tailscale_device.worker[name].addresses[1]] // , data.tailscale_device.worker[name].addresses[0]]
  ])
  skip_kubernetes_checks = true
  endpoints              = [local.dns_loadbalancer_hostname]
}

resource "talos_cluster_kubeconfig" "this" {
  count                = length(local.control_plane_nodes) > 0 ? 1 : 0
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = one(data.talos_cluster_health.this.0.control_plane_nodes)
}
