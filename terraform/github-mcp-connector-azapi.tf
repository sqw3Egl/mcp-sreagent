resource "azapi_update_resource" "github_mcp_connector" {
  type        = "Microsoft.App/agents@2026-01-01"
  resource_id = local.agent_resource_id

  # The public ARM schema does not currently document the full MCP server payload.
  # Note: `schema_validation_enabled` is not supported on `azapi_update_resource`.
  body = {
    properties = {
      mcpServers = [
        {
          name                    = "githubmcp"
          type                    = "mcp"
          partnerType             = "GitHub"
          endpoint                = "https://${azurerm_container_app.github_mcp.latest_revision_fqdn}/mcp"
          selectedTools           = var.github_selected_tools
          toolsVisibleToMetaAgent = true
        }
      ]
    }
  }

  depends_on = [azurerm_container_app.github_mcp]
}
