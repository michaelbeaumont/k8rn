provider "cloudflare" {
  api_token = var.cloudflare_token
}

resource "cloudflare_record" "cp" {
  for_each = toset([for node in var.control_plane_nodes : node.tailscale_ip])
  zone_id  = var.cloudflare_zone_id
  name     = var.cluster_name
  value    = each.value
  type     = "A"
  ttl      = 3600
}
