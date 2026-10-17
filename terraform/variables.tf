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

variable "github_selected_tools" {
  type = list(string)
  default = [
    "create_branch",
    "create_or_update_file",
    "create_repository",
    "delete_file",
    "fork_repository",
    "get_commit",
    "get_file_contents",
    "get_latest_release",
    "get_release_by_tag",
    "get_tag",
    "list_branches",
    "list_commits",
    "list_releases",
    "list_repository_collaborators",
    "list_tags",
    "push_files",
    "search_code",
    "search_commits",
    "search_repositories",
  ]
}

variable "additional_tools" {
  type    = string
  default = "create_pull_request,merge_pull_request,update_pull_request"
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

variable "github_mcp_image_repository" {
  type    = string
  default = "mcp/github-app-mcp"
}

variable "github_mcp_image_tag" {
  type    = string
  default = "1.0.6"
}

variable "container_port" {
  type    = number
  default = 8000
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

# Cheapest uksouth size with quota that meets the AKS system pool minimum
# (2 vCPU / 4 GiB). B-series v2 has 0 quota and B2s (v1) isn't offered.
variable "aks_node_vm_size" {
  type    = string
  default = "Standard_D2als_v6"
}

variable "aks_node_count" {
  type    = number
  default = 1
}
