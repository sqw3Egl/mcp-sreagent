resource "azurerm_container_app_environment" "this" {
  name                       = "${var.prefix}-cae"
  location                   = azurerm_virtual_network.uks_vnet_vnet.location
  resource_group_name        = azurerm_resource_group.uks_sreagent_rsg.name
  infrastructure_subnet_id   = azurerm_subnet.resources.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.uks_sreagent.id
  tags                       = var.tags
}

resource "azurerm_container_app" "github_mcp" {
  name                         = "${var.prefix}-app"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.uks_sreagent_rsg.name
  revision_mode                = "Single"
  tags                         = var.tags

  depends_on = [
    azurerm_role_assignment.github_mcp_acr_pull,
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uks_sreagent_identity.id]
  }

  secret {
    name                = "github-app-private-key"
    identity            = azurerm_user_assigned_identity.uks_sreagent_identity.id
    key_vault_secret_id = azurerm_key_vault_secret.github_app_private_key.id
  }

  registry {
    server   = azurerm_container_registry.github_mcp.login_server
    identity = azurerm_user_assigned_identity.uks_sreagent_identity.id
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
      name  = "github-mcp-server"
      image = local.github_mcp_image
      args = [
        "--stdio",
        "python3 /app/wrapper.py",
        "--port",
        tostring(var.container_port),
        "--outputTransport",
        "streamableHttp",
      ]
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

      env {
        name  = "GITHUB_TOOLSETS"
        value = "repos"
      }

      env {
        name = "GITHUB_TOOLS"
        value = var.additional_tools
      }

      startup_probe {
        transport               = "TCP"
        port                    = var.container_port
        initial_delay           = 5
        interval_seconds        = 10
        failure_count_threshold = 18
        timeout                 = 5
      }

      readiness_probe {
        transport               = "TCP"
        port                    = var.container_port
        initial_delay           = 3
        interval_seconds        = 10
        failure_count_threshold = 3
        success_count_threshold = 1
        timeout                 = 5
      }

      liveness_probe {
        transport               = "TCP"
        port                    = var.container_port
        initial_delay           = 30
        interval_seconds        = 30
        failure_count_threshold = 3
        timeout                 = 5
      }
    }
  }
}

output "github_mcp_server_url" {
  value = "https://${azurerm_container_app.github_mcp.latest_revision_fqdn}/mcp"
}

output "github_mcp_image" {
  value = local.github_mcp_image
}

output "github_mcp_identity_resource_id" {
  value = azurerm_user_assigned_identity.uks_sreagent_identity.id
}

output "github_mcp_acr_name" {
  value = azurerm_container_registry.github_mcp.name
}
