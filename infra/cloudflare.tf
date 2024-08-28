data "cloudflare_zone" "this" {
  name = var.cloudflare_zone
}

resource "cloudflare_record" "cp_a" {
  for_each = data.tailscale_device.cp
  zone_id  = data.cloudflare_zone.this.zone_id
  name     = var.cluster_name
  content  = each.value.addresses[0]
  type     = "A"
  ttl      = 3600
  comment  = "Talos control plane node"
}

resource "cloudflare_record" "cp_aaaa" {
  for_each = data.tailscale_device.cp
  zone_id  = data.cloudflare_zone.this.zone_id
  name     = var.cluster_name
  content  = each.value.addresses[1]
  type     = "AAAA"
  ttl      = 3600
  comment  = "Talos control plane node"
}
