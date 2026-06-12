resource "azurerm_resource_group" "todelete_rsg" {
  name     = "todelete-rsg"
  location = "uksouth"
}

resource "azurerm_resource_group" "uks_vnet_rsg" {
  name     = "uks-vnet-rsg"
  location = "uksouth"
}

resource "azurerm_resource_group" "uks_law_rsg" {
  name     = "uks-law-rsg"
  location = "uksouth"
}


resource "azurerm_resource_group" "uks_keyvault_rsg" {
  name     = "uks-keyvault-rsg"
  location = "uksouth"
}

resource "azurerm_resource_group" "networkwatcher_rg" {
  name     = "NetworkWatcherRG"
  location = "uksouth"
}

resource "azurerm_resource_group" "rg_andy_5555" {
  name     = "rg-andy-5555"
  location = "uksouth"
}

resource "azurerm_resource_group" "uks_sreagent_rsg" {
  name     = "uks-sreagent-rsg"
  location = "eastus2"
}
