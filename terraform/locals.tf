locals {
  agent_resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/agents/${var.agent_name}"

  tenant_id = "21cf3499-0582-4344-9a87-78253166a61a"

  github_mcp_acr_name = substr(lower(replace("${var.prefix}acr${var.subscription_id}", "-", "")), 0, 50)
  github_mcp_image    = "${azurerm_container_registry.github_mcp.login_server}/${var.github_mcp_image_repository}:${var.github_mcp_image_tag}"
}
