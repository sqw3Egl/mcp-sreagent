### PRIVATE DNS ZONES ###

resource "azurerm_private_dns_zone" "privatelink_vaultcore_azure_net" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.uks_vnet_rsg.name
}

resource "azurerm_private_dns_zone" "privatelink_azurecontainerapps_io" {
  name                = local.github_mcp_private_dns_zone_name
  resource_group_name = azurerm_resource_group.uks_vnet_rsg.name
}

### DNS LINKS TO VNET ###
resource "azurerm_private_dns_zone_virtual_network_link" "privatelink_vaultcore_link" {
  name                  = "6tfur7earvj6q"
  resource_group_name   = azurerm_resource_group.uks_vnet_rsg.name
  private_dns_zone_name = azurerm_private_dns_zone.privatelink_vaultcore_azure_net.name
  virtual_network_id    = azurerm_virtual_network.uks_vnet_vnet.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "privatelink_azurecontainerapps_link" {
  name                  = "${var.prefix}-cae-dns-link"
  resource_group_name   = azurerm_resource_group.uks_vnet_rsg.name
  private_dns_zone_name = azurerm_private_dns_zone.privatelink_azurecontainerapps_io.name
  virtual_network_id    = azurerm_virtual_network.uks_vnet_vnet.id
  registration_enabled  = false
}


### A RECORDS ###

resource "azurerm_private_dns_a_record" "uks_keyvault_kv" {
  name                = "uks-keyvault-kv"
  zone_name           = azurerm_private_dns_zone.privatelink_vaultcore_azure_net.name
  resource_group_name = azurerm_resource_group.uks_vnet_rsg.name
  ttl                 = 3600
  records             = ["10.0.0.68"]
}

resource "azurerm_private_dns_a_record" "uks_containerenv_dns" {
  name                = local.github_mcp_private_dns_record_name
  zone_name           = azurerm_private_dns_zone.privatelink_azurecontainerapps_io.name
  resource_group_name = azurerm_resource_group.uks_vnet_rsg.name
  ttl                 = 3600
  records             = [azurerm_private_endpoint.uk_containerenv_pe.private_service_connection[0].private_ip_address]
}
