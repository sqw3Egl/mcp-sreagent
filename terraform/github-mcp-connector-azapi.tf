resource "azapi_resource" "github_mcp_connector" {
  type                      = "Microsoft.App/agents/connectors@2025-05-01-preview"
  name                      = "githubcustommcp"
  parent_id                 = local.agent_resource_id
  schema_validation_enabled = false

  body = {
    properties = {
      dataConnectorType = "Mcp"
      dataSource        = "https://${azurerm_container_app.github_mcp.latest_revision_fqdn}/mcp"
    }
  }
}
