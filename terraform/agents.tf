resource "azapi_resource" "uks_sreagent_1" {
  type                      = "Microsoft.App/agents@2026-01-01"
  name                      = "uks-sreagent-2"
  parent_id                 = azurerm_resource_group.uks_sreagent_rsg.id
  location                  = "uksouth"
  schema_validation_enabled = false

  depends_on = [
    azurerm_role_assignment.uks_sreagent_agent_reader,
  ]

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
          appId            = azurerm_application_insights.uks_sreagent.app_id
          connectionString = azurerm_application_insights.uks_sreagent.connection_string
        }
      }
      mcpServers = []
      # Caps active-flow usage only (minimum 500). The always-on charge
      # (4 AAU/hour) applies for as long as the agent exists.
      monthlyAgentUnitLimit = 500
      upgradeChannel        = "Preview"
      vnetConfiguration = {
        subnetResourceId = azurerm_subnet.sreagent.id
      }
      # Required alongside vnetConfiguration: route sandbox egress through the VNet
      # and resolve private endpoints (e.g. Key Vault) via the VNet's private DNS.
      sandboxConfiguration = {
        egress = {
          mode = "AzureVNet"
          # The SREAgent subnet has no internet egress, so ARM and Entra ID sign-in
          # go via the agent's infra network. In an enterprise hub/spoke these would
          # instead be FQDN rules on the hub firewall.
          allowedHosts                    = ["management.azure.com", "login.microsoftonline.com"]
          allowedRegistries               = []
          allowedCodeRepositories         = ["Github"]
          allowHttpMcpServerNetworkAccess = false
          vnetConfiguration = {
            usePrivateDnsResolution = true
          }
        }
      }
    }
  }
}
