resource "azurerm_private_dns_zone" "privatelink_vaultcore_azure_net" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.uks_vnet_rsg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "privatelink_vaultcore_link" {
  name                  = "6tfur7earvj6q"
  resource_group_name   = azurerm_resource_group.uks_vnet_rsg.name
  private_dns_zone_name = azurerm_private_dns_zone.privatelink_vaultcore_azure_net.name
  virtual_network_id    = azurerm_virtual_network.uks_vnet_vnet.id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "uks_keyvault_kv" {
  name                = "uks-keyvault-kv"
  zone_name           = azurerm_private_dns_zone.privatelink_vaultcore_azure_net.name
  resource_group_name = azurerm_resource_group.uks_vnet_rsg.name
  ttl                 = 3600
  records             = ["10.0.0.68"]
}
