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

