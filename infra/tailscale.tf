provider "tailscale" {
  oauth_client_id     = var.tailnet_oauth_client_id
  oauth_client_secret = var.tailnet_oauth_client_secret
}

resource "tailscale_tailnet_key" "unsigned-cp" {
  for_each      = toset([for node in var.control_plane_nodes : node.local_ip])
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
  tags = [
    "tag:infra",
    "tag:cname-k8rn",
    "tag:k8rn-cp",
    "tag:${local.hostnames[each.value]}",
  ]
}

data "tailscale_device" "cp" {
  for_each = toset([for node in var.control_plane_nodes : node.local_ip])
  hostname = local.hostnames[talos_machine_configuration_apply.this[each.value].node]
  wait_for = "10m"
}
