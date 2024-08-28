data "tailscale_device" "external_server" {
  hostname = var.external_server_hostname
  wait_for = "30s"
}
