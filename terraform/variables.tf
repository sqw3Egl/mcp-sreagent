variable "subscription_id" {
  type    = string
  default = "0433d2b6-3aa6-4751-95d8-ad50c815ede0"
}

variable "resource_group_name" {
  type    = string
  default = "uks-sreagent-rsg"
}

variable "agent_name" {
  type    = string
  default = "uks-sreagent-2"
}

variable "github_mcp_endpoint" {
  type    = string
  default = "https://example.com"
}

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

variable "location" {
  type    = string
  default = "uksouth"
}

variable "prefix" {
  type    = string
  default = "github-mcp"
}

variable "key_vault_name" {
  type    = string
  default = "uks-keyvault-kv"
}

variable "github_mcp_image" {
  type    = string
  # Placeholder image for planning; replace with actual MCP image.
  default = "mcp/github"
}

variable "container_port" {
  type    = numbermcpp
  default = 8080
}

variable "github_app_id" {
  type    = string
  default = "4021906"
}

variable "github_app_installation_id" {
  type    = string
  default = "139457421"
}

variable "github_app_private_key_pem" {
  type      = string
  sensitive = true
  default   = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
