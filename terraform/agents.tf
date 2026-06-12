resource "azapi_resource" "uks_sreagent_1" {
  type      = "Microsoft.App/agents@2026-01-01"
  name      = "uks-sreagent-2"
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

resource "azurerm_user_assigned_identity" "uks_sreagent_identity" {
  name                = "uks-sreagent-1-vxfjfmeby4z7w"
  location            = azurerm_resource_group.uks_sreagent_rsg.location
  resource_group_name = azurerm_resource_group.uks_sreagent_rsg.name
  
}


resource "azurerm_role_assignment" "uks_sreagent_agent_kvadmin" {
  scope                = azurerm_key_vault.uks_keyvault_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

resource "azurerm_role_assignment" "uks_sreagent_agent_contributor" {
  scope                = data.azurerm_client_config.current.subscription_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}