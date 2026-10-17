### AGENT UAMI ###

resource "azurerm_user_assigned_identity" "uks_sreagent_identity" {
  name                = "uks-sreagent-1-vxfjfmeby4z7w"
  location            = azurerm_resource_group.uks_sreagent_rsg.location
  resource_group_name = azurerm_resource_group.uks_sreagent_rsg.name

}

### ROLE ASSIGNMENTS ###

# Least privilege for the SRE agent: read everything, manage Azure Monitor alerts,
# and Kubernetes access limited to the test workload's namespace. Changes outside
# that go through the agent's on-behalf-of (OBO) elevation in review mode.

resource "azurerm_role_assignment" "uks_sreagent_agent_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

resource "azurerm_role_assignment" "uks_sreagent_agent_monitoring_contributor" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

# Fetch an Entra ID (non-admin) kubeconfig for the cluster.
resource "azurerm_role_assignment" "uks_sreagent_aks_cluster_user" {
  scope                = azurerm_kubernetes_cluster.uks_aks_aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

# Read workloads/events in all namespaces for diagnosis (no secrets, no RBAC objects).
resource "azurerm_role_assignment" "uks_sreagent_aks_rbac_reader" {
  scope                = azurerm_kubernetes_cluster.uks_aks_aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

# Restart / scale / roll back / edit the test app, in its namespace only.
resource "azurerm_role_assignment" "uks_sreagent_aks_rbac_writer_test_app" {
  scope                = "${azurerm_kubernetes_cluster.uks_aks_aks.id}/namespaces/aks-test-app"
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

resource "azurerm_role_assignment" "uks_sreagent_agent_kvadmin" {
  scope                = azurerm_key_vault.uks_keyvault_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

resource "azurerm_role_assignment" "github_mcp_kv_secrets_user" {
  scope                = azurerm_key_vault.uks_keyvault_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}

# Lets whoever runs terraform write secrets to the RBAC-enabled vault.
resource "azurerm_role_assignment" "uks_keyvault_deployer_secrets_officer" {
  scope                = azurerm_key_vault.uks_keyvault_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# DISABLED (least privilege): the agent identity no longer needs these. AcrPull
# was for the container app; restore it if that is re-enabled.
#
# resource "azurerm_role_assignment" "uks_sreagent_agent_contributor" {
#   scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
#   role_definition_name = "Contributor"
#   principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
# }
#
# resource "azurerm_role_assignment" "github_mcp_acr_pull" {
#   scope                = azurerm_container_registry.github_mcp.id
#   role_definition_name = "AcrPull"
#   principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
# }
