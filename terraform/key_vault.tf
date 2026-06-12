resource "azurerm_key_vault" "uks_keyvault_kv" {
  name                          = "uks-keyvault-kv"
  location                      = azurerm_resource_group.uks_keyvault_rsg.location
  resource_group_name           = azurerm_resource_group.uks_keyvault_rsg.name
  tenant_id                     = local.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = true
  soft_delete_retention_days    = 90

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = [
        "20.90.100.16/32",
        "83.67.195.205/32"
    ]
  }
}

resource "azurerm_private_endpoint" "uk_keyvault_pe" {
  name                = "uk-keyvault-pe"
  location            = azurerm_resource_group.uks_keyvault_rsg.location
  resource_group_name = azurerm_resource_group.uks_keyvault_rsg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "uk-keyvault-pe_85cb7dae-2fc0-40ba-8053-2eeb3895a09f"
    private_connection_resource_id = azurerm_key_vault.uks_keyvault_kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

# This NIC is created as part of the private endpoint. It is exported with AzAPI so
# the current subscription inventory can still be imported without inventing a fake
# standalone azurerm network interface configuration.
# resource "azapi_resource" "uk_keyvault_pe_nic" {
#   type      = "Microsoft.Network/networkInterfaces@2024-05-01"
#   name      = "uk-keyvault-pe.nic.3c0d3f96-f10a-4600-b234-46cfcfde5183"
#   parent_id = azurerm_resource_group.uks_keyvault_rsg.id
#   location  = azurerm_resource_group.uks_keyvault_rsg.location
#   schema_validation_enabled = false
#   body = {
#     properties = {
#       privateEndpoint = {
#         id = azurerm_private_endpoint.uk_keyvault_pe.id
#       }
#       ipConfigurations = [
#         {
#           name = "privateEndpointIpConfig.e7543d5f-b719-4e8f-9453-44519ebc397a"
#           properties = {
#             privateIPAddress          = "10.0.0.68"
#             privateIPAllocationMethod = "Dynamic"
#             privateLinkConnectionProperties = {
#               fqdns = [
#                 "uks-keyvault-kv.vault.azure.net"
#               ]
#               groupId            = "vault"
#               requiredMemberName = "default"
#             }
#           }
#         }
#       ]
#     }
#   }
# }

resource "azurerm_key_vault_secret" "github_app_private_key" {
  name         = "github-app-private-key-pem"
  value        = var.github_app_private_key_pem
  key_vault_id = azurerm_key_vault.uks_keyvault_kv.id

  tags = var.tags
}

resource "azurerm_role_assignment" "github_mcp_kv_secrets_user" {
  scope                = azurerm_key_vault.uks_keyvault_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.uks_sreagent_identity.principal_id
}
