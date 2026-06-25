resource "azurerm_container_registry" "github_mcp" {
  name                = local.github_mcp_acr_name
  resource_group_name = azurerm_resource_group.uks_sreagent_rsg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

