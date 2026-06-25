### AGENT UAMI ###

resource "azurerm_user_assigned_identity" "uks_sreagent_identity" {
  name                = "uks-sreagent-1-vxfjfmeby4z7w"
  location            = azurerm_resource_group.uks_sreagent_rsg.location
  resource_group_name = azurerm_resource_group.uks_sreagent_rsg.name
  
}

### ROLE ASSIGNMENTS ###

resource "azurerm_role_assignment" "uks_sreagent_agent_contributor" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

resource "azurerm_role_assignment" "uks_sreagent_agent_kvadmin" {
  scope                = azurerm_key_vault.uks_keyvault_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

resource "azurerm_role_assignment" "github_mcp_kv_secrets_user" {
  scope                = azurerm_key_vault.uks_keyvault_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

resource "azurerm_role_assignment" "github_mcp_acr_pull" {
  scope                = azurerm_container_registry.github_mcp.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}
