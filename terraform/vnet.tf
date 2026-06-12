resource "azurerm_network_watcher" "uksouth" {
  name                = "NetworkWatcher_uksouth"
  location            = azurerm_resource_group.networkwatcher_rg.location
  resource_group_name = azurerm_resource_group.networkwatcher_rg.name
}

resource "azurerm_virtual_network" "uks_vnet_vnet" {
  name                = "uks-vnet-vnet"
  location            = azurerm_resource_group.uks_vnet_rsg.location
  resource_group_name = azurerm_resource_group.uks_vnet_rsg.name
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "sreagent" {
  name                 = "SREAgent"
  resource_group_name  = azurerm_resource_group.uks_vnet_rsg.name
  virtual_network_name = azurerm_virtual_network.uks_vnet_vnet.name
  address_prefixes     = ["10.0.0.0/27"]
  service_endpoints    = ["Microsoft.KeyVault"]

  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Disabled"

  delegation {
    name = "Microsoft.App/environments"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

resource "azurerm_subnet" "resources" {
  name                 = "Resources"
  resource_group_name  = azurerm_resource_group.uks_vnet_rsg.name
  virtual_network_name = azurerm_virtual_network.uks_vnet_vnet.name
  address_prefixes     = ["10.0.0.32/27"]

  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "PrivateEndpoints"
  resource_group_name  = azurerm_resource_group.uks_vnet_rsg.name
  virtual_network_name = azurerm_virtual_network.uks_vnet_vnet.name
  address_prefixes     = ["10.0.0.64/27"]

  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Disabled"
}
