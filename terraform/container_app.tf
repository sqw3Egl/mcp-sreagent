
resource "azurerm_container_app_environment" "this" {
  name                       = "${var.prefix}-cae"
  location                   = azurerm_resource_group.uks_sreagent_rsg.location
  resource_group_name        = azurerm_resource_group.uks_sreagent_rsg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.uks_sreagent.id
  tags                       = var.tags
}

resource "azurerm_container_app" "github_mcp" {
  name                         = "${var.prefix}-app-2"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.uks_sreagent_rsg.name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uks_sreagent_identity.id]
  }

  secret {
    name                = "github-app-private-key"
    identity            = azurerm_user_assigned_identity.uks_sreagent_identity.id
    key_vault_secret_id = azurerm_key_vault_secret.github_app_private_key.id
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
      name   = "github-mcp-server-2"
      image  = var.github_mcp_image
      cpu    = 0.5
      memory = "1Gi"

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
}

output "github_mcp_server_url" {
  value = "https://${azurerm_container_app.github_mcp.latest_revision_fqdn}"
}

output "github_mcp_identity_resource_id" {
  value = azurerm_user_assigned_identity.uks_sreagent_identity.id
}


