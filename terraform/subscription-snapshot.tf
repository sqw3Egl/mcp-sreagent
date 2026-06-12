terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azapi" {}

variable "subscription_id" {
  type    = string
  default = "0433d2b6-3aa6-4751-95d8-ad50c815ede0"
}

locals {
  tenant_id = "21cf3499-0582-4344-9a87-78253166a61a"
}

resource "azurerm_resource_group" "todelete_rsg" {
  name     = "todelete-rsg"
  location = "uksouth"
}

resource "azurerm_resource_group" "uks_vnet_rsg" {
  name     = "uks-vnet-rsg"
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

resource "azurerm_key_vault" "uks_keyvault_kv" {
  name                          = "uks-keyvault-kv"
  location                      = azurerm_resource_group.uks_keyvault_rsg.location
  resource_group_name           = azurerm_resource_group.uks_keyvault_rsg.name
  tenant_id                     = local.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = true
  soft_delete_retention_days    = 90

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = ["20.90.100.16/32"]
  }
}

resource "azurerm_private_endpoint" "uk_keyvault_pe" {
  name                = "uk-keyvault-pe"
  location            = azurerm_resource_group.uks_keyvault_rsg.location
  resource_group_name = azurerm_resource_group.uks_keyvault_rsg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "uk-keyvault-pe_85cb7dae-2fc0-40ba-8053-2eeb3895a09f"
    private_connection_resource_id = azurerm_key_vault.uks_keyvault_kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

# This NIC is created as part of the private endpoint. It is exported with AzAPI so
# the current subscription inventory can still be imported without inventing a fake
# standalone azurerm network interface configuration.
resource "azapi_resource" "uk_keyvault_pe_nic" {
  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "uk-keyvault-pe.nic.3c0d3f96-f10a-4600-b234-46cfcfde5183"
  parent_id = azurerm_resource_group.uks_keyvault_rsg.id
  location  = azurerm_resource_group.uks_keyvault_rsg.location

  schema_validation_enabled = false

  body = {
    properties = {
      privateEndpoint = {
        id = azurerm_private_endpoint.uk_keyvault_pe.id
      }
      ipConfigurations = [
        {
          name = "privateEndpointIpConfig.e7543d5f-b719-4e8f-9453-44519ebc397a"
          properties = {
            privateIPAddress          = "10.0.0.68"
            privateIPAllocationMethod = "Dynamic"
            privateLinkConnectionProperties = {
              fqdns = [
                "uks-keyvault-kv.vault.azure.net"
              ]
              groupId            = "vault"
              requiredMemberName = "default"
            }
          }
        }
      ]
    }
  }
}

resource "azurerm_network_watcher" "uksouth" {
  name                = "NetworkWatcher_uksouth"
  location            = azurerm_resource_group.networkwatcher_rg.location
  resource_group_name = azurerm_resource_group.networkwatcher_rg.name
}

resource "azurerm_user_assigned_identity" "uks_sreagent_identity" {
  name                = "uks-sreagent-1-vxfjfmeby4z7w"
  location            = azurerm_resource_group.uks_sreagent_rsg.location
  resource_group_name = azurerm_resource_group.uks_sreagent_rsg.name
}

resource "azurerm_log_analytics_workspace" "uks_sreagent" {
  name                = "workspacevxfjfmeby4z7w"
  location            = "uksouth"
  resource_group_name = azurerm_resource_group.uks_sreagent_rsg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = -1

  internet_ingestion_enabled      = true
  internet_query_enabled          = true
  allow_resource_only_permissions = true
}

resource "azurerm_application_insights" "uks_sreagent" {
  name                = "uks-sreagent-1-9ea6b9b1-8dbe-app-insights"
  location            = "uksouth"
  resource_group_name = azurerm_resource_group.uks_sreagent_rsg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.uks_sreagent.id
  retention_in_days   = 90

  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

resource "azurerm_monitor_action_group" "application_insights_smart_detection" {
  name                = "Application Insights Smart Detection"
  resource_group_name = azurerm_resource_group.uks_sreagent_rsg.name
  location            = "global"
  short_name          = "SmartDetect"
  enabled             = true

  arm_role_receiver {
    name                    = "Monitoring Contributor"
    role_id                 = "749f88d5-cbae-40b8-bcfc-e573ddc772fa"
    use_common_alert_schema = true
  }

  arm_role_receiver {
    name                    = "Monitoring Reader"
    role_id                 = "43d0d8ad-25c7-4714-9337-8ba259a9fe05"
    use_common_alert_schema = true
  }
}

resource "azapi_resource" "uks_sreagent_1" {
  type      = "Microsoft.App/agents@2026-01-01"
  name      = "uks-sreagent-1"
  parent_id = azurerm_resource_group.uks_sreagent_rsg.id
  location  = "uksouth"

  schema_validation_enabled = false

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uks_sreagent_identity.id]
  }

  body = {
    properties = {
      actionConfiguration = {
        accessLevel = "Low"
        identity    = azurerm_user_assigned_identity.uks_sreagent_identity.id
        mode        = "review"
      }
      defaultModel = {
        name     = "Automatic"
        provider = "MicrosoftFoundry"
      }
      experimentalSettings = {
        EnableConnectorsV2   = true
        EnableSandboxGroup   = true
        EnableV2AgentLoop    = true
        EnableWorkspaceTools = true
      }
      knowledgeGraphConfiguration = {
        identity = azurerm_user_assigned_identity.uks_sreagent_identity.id
        managedResources = [
          "/subscriptions/${var.subscription_id}"
        ]
      }
      logConfiguration = {
        applicationInsightsConfiguration = {
          applicationInsightsResourceId = azurerm_application_insights.uks_sreagent.id
        }
      }
      mcpServers            = []
      monthlyAgentUnitLimit = 10000
      upgradeChannel        = "Preview"
      vnetConfiguration = {
        subnetResourceId = azurerm_subnet.sreagent.id
      }
    }
  }
}

import {
  to = azurerm_resource_group.todelete_rsg
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/todelete-rsg"
}

import {
  to = azurerm_resource_group.uks_vnet_rsg
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg"
}

import {
  to = azurerm_resource_group.uks_keyvault_rsg
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-keyvault-rsg"
}

import {
  to = azurerm_resource_group.networkwatcher_rg
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/NetworkWatcherRG"
}

import {
  to = azurerm_resource_group.rg_andy_5555
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/rg-andy-5555"
}

import {
  to = azurerm_resource_group.uks_sreagent_rsg
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg"
}

import {
  to = azurerm_virtual_network.uks_vnet_vnet
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/virtualNetworks/uks-vnet-vnet"
}

import {
  to = azurerm_subnet.sreagent
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/virtualNetworks/uks-vnet-vnet/subnets/SREAgent"
}

import {
  to = azurerm_subnet.resources
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/virtualNetworks/uks-vnet-vnet/subnets/Resources"
}

import {
  to = azurerm_subnet.private_endpoints
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/virtualNetworks/uks-vnet-vnet/subnets/PrivateEndpoints"
}

import {
  to = azurerm_private_dns_zone.privatelink_vaultcore_azure_net
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
}

import {
  to = azurerm_private_dns_zone_virtual_network_link.privatelink_vaultcore_link
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/virtualNetworkLinks/6tfur7earvj6q"
}

import {
  to = azurerm_private_dns_a_record.uks_keyvault_kv
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/A/uks-keyvault-kv"
}

import {
  to = azurerm_key_vault.uks_keyvault_kv
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-keyvault-rsg/providers/Microsoft.KeyVault/vaults/uks-keyvault-kv"
}

import {
  to = azurerm_private_endpoint.uk_keyvault_pe
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-keyvault-rsg/providers/Microsoft.Network/privateEndpoints/uk-keyvault-pe"
}

import {
  to = azapi_resource.uk_keyvault_pe_nic
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-keyvault-rsg/providers/Microsoft.Network/networkInterfaces/uk-keyvault-pe.nic.3c0d3f96-f10a-4600-b234-46cfcfde5183"
}

import {
  to = azurerm_network_watcher.uksouth
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_uksouth"
}

import {
  to = azurerm_user_assigned_identity.uks_sreagent_identity
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uks-sreagent-1-vxfjfmeby4z7w"
}

import {
  to = azurerm_log_analytics_workspace.uks_sreagent
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg/providers/Microsoft.OperationalInsights/workspaces/workspacevxfjfmeby4z7w"
}

import {
  to = azurerm_application_insights.uks_sreagent
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg/providers/Microsoft.Insights/components/uks-sreagent-1-9ea6b9b1-8dbe-app-insights"
}

import {
  to = azurerm_monitor_action_group.application_insights_smart_detection
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg/providers/microsoft.insights/actiongroups/Application Insights Smart Detection"
}

import {
  to = azapi_resource.uks_sreagent_1
  id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg/providers/Microsoft.App/agents/uks-sreagent-1"
}
