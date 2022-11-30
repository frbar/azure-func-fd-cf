resource "cloudflare_record" "poc_cname" {
  zone_id = var.cf_zone_id
  name    = var.env_name
  value   = azurerm_cdn_frontdoor_endpoint.poc.host_name
  type    = "CNAME"
  ttl     = 1
  proxied = true
  lifecycle {
    ignore_changes = [
      proxied,
    ]
  }
}

resource "cloudflare_record" "poc_txt" {
  zone_id = var.cf_zone_id
  name    = "_dnsauth.${var.env_name}"
  value   = azurerm_cdn_frontdoor_custom_domain.poc.validation_token
  type    = "TXT"
  proxied = false
  ttl     = 3600
}