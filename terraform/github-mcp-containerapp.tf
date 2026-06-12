terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}

variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
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
  type = string
}

variable "github_mcp_image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "github_app_id" {
  type = string
}

variable "github_app_installation_id" {
  type = string
}

# For production, prefer populating this secret out of band so the private key
# does not originate from Terraform input/state.
variable "github_app_private_key_pem" {
  type      = string
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.prefix}-law"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "github_mcp" {
  name                = "${var.prefix}-uai"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_key_vault" "this" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.this.location
  resource_group_name         = azurerm_resource_group.this.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7
  enable_rbac_authorization   = true
  public_network_access_enabled = true
  tags                        = var.tags
}

resource "azurerm_key_vault_secret" "github_app_private_key" {
  name         = "github-app-private-key-pem"
  value        = var.github_app_private_key_pem
  key_vault_id = azurerm_key_vault.this.id

  tags = var.tags
}

resource "azurerm_role_assignment" "github_mcp_kv_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.github_mcp.principal_id
}

resource "azurerm_container_app_environment" "this" {
  name                       = "${var.prefix}-cae"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = var.tags
}

resource "azurerm_container_app" "github_mcp" {
  name                         = "${var.prefix}-app"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.github_mcp.id]
  }

  secret {
    name                = "github-app-private-key"
    identity            = azurerm_user_assigned_identity.github_mcp.id
    key_vault_secret_id = azurerm_key_vault_secret.github_app_private_key.versionless_id
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = var.container_port
    transport                  = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name   = "github-mcp-server"
      image  = var.github_mcp_image
      cpu    = 0.5
      memory = "1Gi"

      # Adjust these environment variable names to match the MCP server image.
      env {
        name  = "PORT"
        value = tostring(var.container_port)
      }

      env {
        name  = "GITHUB_APP_ID"
        value = var.github_app_id
      }

      env {
        name  = "GITHUB_APP_INSTALLATION_ID"
        value = var.github_app_installation_id
      }

      env {
        name        = "GITHUB_APP_PRIVATE_KEY"
        secret_name = "github-app-private-key"
      }
    }
  }

  depends_on = [azurerm_role_assignment.github_mcp_kv_secrets_user]
}

output "github_mcp_server_url" {
  value = "https://${azurerm_container_app.github_mcp.latest_revision_fqdn}"
}

output "github_mcp_identity_resource_id" {
  value = azurerm_user_assigned_identity.github_mcp.id
}
