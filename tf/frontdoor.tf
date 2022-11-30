resource "azurerm_cdn_frontdoor_profile" "poc" {
  name                = "${var.env_name}-fd"
  resource_group_name = azurerm_resource_group.poc.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "poc" {
  name                     = "${var.env_name}-fd"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.poc.id
}

resource "azurerm_cdn_frontdoor_origin_group" "poc" {
  name                     = "${var.env_name}-func-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.poc.id
  session_affinity_enabled = false

  health_probe {
    interval_in_seconds = 15
    path                = "/api/health"
    protocol            = "Http"
    request_type        = "GET"
  }

  load_balancing {
    additional_latency_in_milliseconds = 100
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "poc" {
  count                         = 2
  name                          = "${var.env_name}-func-${count.index}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.poc.id
  enabled                       = true

  certificate_name_check_enabled = false

  host_name          = azurerm_windows_function_app.poc[count.index].default_hostname
  http_port          = 80
  https_port         = 443
  origin_host_header = azurerm_windows_function_app.poc[count.index].default_hostname
  priority           = 1
  weight             = 1000
}

resource "azurerm_cdn_frontdoor_route" "poc" {
  name                          = "${var.env_name}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.poc.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.poc.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.poc[0].id, azurerm_cdn_frontdoor_origin.poc[1].id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain         = true
  cdn_frontdoor_rule_set_ids     = [ azurerm_cdn_frontdoor_rule_set.poc.id ]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.poc.id]
}

resource "azurerm_cdn_frontdoor_rule_set" "poc" {
  name                     = "headers"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.poc.id
}

resource "azurerm_cdn_frontdoor_rule" "poc" {
  depends_on = [azurerm_cdn_frontdoor_origin_group.poc, azurerm_cdn_frontdoor_origin.poc]

  name                      = "headers"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.poc.id
  order                     = 1
  behavior_on_match         = "Continue"

  actions {
      request_header_action {
        header_action = "Overwrite"
        header_name   = "x-functions-key"
        value         = random_password.function_key.result
      }
  }

  conditions {
    host_name_condition {
      operator         = "Any"
      negate_condition = false
    }
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "poc" {
  name                     = "${var.env_name}-custom-domain"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.poc.id
  host_name                = "${var.env_name}.${var.cf_domain}"

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "poc" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.poc.id
  cdn_frontdoor_route_ids        = [
    azurerm_cdn_frontdoor_route.poc.id
  ]
}