provider "tailscale" {
  oauth_client_id     = var.tailnet_oauth_client_id
  oauth_client_secret = var.tailnet_oauth_client_secret
}

resource "tailscale_tailnet_key" "unsigned-cp" {
  for_each      = toset(keys(var.control_plane_nodes))
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
  tags = [
    "tag:infra",
    "tag:cname-k8rn",
    "tag:k8rn-node",
    "tag:k8rn-cp",
    "tag:${local.hostnames[each.key]}",
  ]
}

resource "tailscale_tailnet_key" "unsigned-worker" {
  for_each      = toset(keys(var.worker_nodes))
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
  tags = [
    "tag:infra",
    "tag:k8rn-node",
    "tag:k8rn-worker",
    "tag:${local.hostnames[each.key]}",
  ]
}


data "tailscale_device" "cp" {
  for_each = toset(keys(var.control_plane_nodes))
  hostname = local.hostnames[talos_machine_configuration_apply.control_plane_init[each.key].node]
  wait_for = "10m"
}

data "tailscale_device" "external_server" {
  hostname = var.external_server_hostname
  wait_for = "30s"
}
