terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
  }
}

provider "azapi" {}

variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "agent_name" {
  type = string
}

variable "github_mcp_endpoint" {
  type = string
}

# Mint this outside the connector from your GitHub App credentials.
# Do not place the GitHub App private key in the SRE Agent connector config.
variable "github_app_installation_token" {
  type      = string
  sensitive = true
}

variable "github_selected_tools" {
  type = list(string)

  default = [
    "githubmcp_get_me",
    "githubmcp_get_file_contents",
    "githubmcp_search_code",
    "githubmcp_search_repositories",
    "githubmcp_pull_request_read",
    "githubmcp_issue_read",
    "githubmcp_list_pull_requests",
    "githubmcp_list_issues"
  ]
}

locals {
  agent_resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/agents/${var.agent_name}"
}

resource "azapi_update_resource" "github_mcp_connector" {
  type        = "Microsoft.App/agents@2026-01-01"
  resource_id = local.agent_resource_id

  # The public ARM schema does not currently document the full MCP server payload.
  # Disable strict schema validation so the preview/runtime shape can be applied.
  schema_validation_enabled = false

  body = {
    properties = {
      mcpServers = [
        {
          name                    = "githubmcp"
          type                    = "mcp"
          partnerType             = "GitHub"
          endpoint                = var.github_mcp_endpoint
          authType                = "BearerToken"
          bearerToken             = var.github_app_installation_token
          selectedTools           = var.github_selected_tools
          toolsVisibleToMetaAgent = true
        }
      ]
    }
  }
}
