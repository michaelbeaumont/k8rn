# This is necessary because of a weird network issues that apparently has to do
# with cloudflare + my ISP + http2

resource "tls_private_key" "image_cache_serve" {
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "image_cache_serve" {
  count           = var.image_cache_ip != "" ? 1 : 0
  private_key_pem = tls_private_key.image_cache_serve.private_key_pem

  validity_period_hours = 1200
  early_renewal_hours   = 3

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  ip_addresses = [var.image_cache_ip]
}
