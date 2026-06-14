resource "azapi_resource" "github_mcp_connector" {
  type      = "Microsoft.App/agents/connectors@2026-01-01"
  name      = "githubmcp"
  parent_id = local.agent_resource_id

  body = {
    properties = {
      dataConnectorType = "Mcp"
      dataSource        = "https://${azurerm_container_app.github_mcp.latest_revision_fqdn}/mcp"
    }
  }
}
