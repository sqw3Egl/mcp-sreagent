
resource "azurerm_log_analytics_workspace" "uks_sreagent" {
  name                = "workspacevxfjfmeby4z7w"
  location            = "uksouth"
  resource_group_name = azurerm_resource_group.uks_law_rsg.name
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
  resource_group_name = azurerm_resource_group.uks_law_rsg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.uks_sreagent.id
  retention_in_days   = 90

  internet_ingestion_enabled = false
  internet_query_enabled     = false
}


