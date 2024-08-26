provider "cloudflare" {
  api_token = var.cloudflare_token
}

resource "cloudflare_record" "cp_a" {
  for_each = data.tailscale_device.cp
  zone_id  = var.cloudflare_zone_id
  name     = var.cluster_name
  value    = each.value.addresses[0]
  type     = "A"
  ttl      = 3600
}

resource "cloudflare_record" "cp_aaaa" {
  for_each = data.tailscale_device.cp
  zone_id  = var.cloudflare_zone_id
  name     = var.cluster_name
  value    = each.value.addresses[1]
  type     = "AAAA"
  ttl      = 3600
}
