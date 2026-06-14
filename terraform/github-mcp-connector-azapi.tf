resource "azapi_resource" "github_mcp_connector" {
  type                      = "Microsoft.App/agents/connectors@2026-01-01"
  name                      = "githubmcpcustom"
  parent_id                 = local.agent_resource_id
  schema_validation_enabled = false

  body = {
    properties = {
      dataConnectorType = "Mcp"
      dataSource        = "githubmcp"
      endpoint          = "https://${azurerm_container_app.github_mcp.latest_revision_fqdn}/mcp"
      extendedProperties = {
        type     = "http"
        endpoint = "https://${azurerm_container_app.github_mcp.latest_revision_fqdn}/mcp"
      }
      identity = "${azurerm_user_assigned_identity.uks_sreagent_identity.id}"
    }
  }
}
