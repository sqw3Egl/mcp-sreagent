# import {
#   to = azurerm_resource_group.todelete_rsg
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/todelete-rsg"
# }

# import {
#   to = azurerm_resource_group.uks_vnet_rsg
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg"
# }

# import {
#   to = azurerm_resource_group.uks_keyvault_rsg
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-keyvault-rsg"
# }

# import {
#   to = azurerm_resource_group.networkwatcher_rg
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/NetworkWatcherRG"
# }

# import {
#   to = azurerm_resource_group.rg_andy_5555
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/rg-andy-5555"
# }

# import {
#   to = azurerm_resource_group.uks_sreagent_rsg
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg"
# }

# import {
#   to = azurerm_virtual_network.uks_vnet_vnet
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/virtualNetworks/uks-vnet-vnet"
# }

# import {
#   to = azurerm_subnet.sreagent
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/virtualNetworks/uks-vnet-vnet/subnets/SREAgent"
# }

# import {
#   to = azurerm_subnet.resources
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/virtualNetworks/uks-vnet-vnet/subnets/Resources"
# }

# import {
#   to = azurerm_subnet.private_endpoints
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/virtualNetworks/uks-vnet-vnet/subnets/PrivateEndpoints"
# }

# import {
#   to = azurerm_private_dns_zone.privatelink_vaultcore_azure_net
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
# }

# import {
#   to = azurerm_private_dns_zone_virtual_network_link.privatelink_vaultcore_link
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/virtualNetworkLinks/6tfur7earvj6q"
# }

# import {
#   to = azurerm_private_dns_a_record.uks_keyvault_kv
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-vnet-rsg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/A/uks-keyvault-kv"
# }

# import {
#   to = azurerm_key_vault.uks_keyvault_kv
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-keyvault-rsg/providers/Microsoft.KeyVault/vaults/uks-keyvault-kv"
# }

# import {
#   to = azurerm_private_endpoint.uk_keyvault_pe
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-keyvault-rsg/providers/Microsoft.Network/privateEndpoints/uk-keyvault-pe"
# }

# import {
#   to = azapi_resource.uk_keyvault_pe_nic
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-keyvault-rsg/providers/Microsoft.Network/networkInterfaces/uk-keyvault-pe.nic.3c0d3f96-f10a-4600-b234-46cfcfde5183"
# }

# import {
#   to = azurerm_network_watcher.uksouth
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_uksouth"
# }

# import {
#   to = azurerm_user_assigned_identity.uks_sreagent_identity
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uks-sreagent-1-vxfjfmeby4z7w"
# }

# import {
#   to = azurerm_log_analytics_workspace.uks_sreagent
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg/providers/Microsoft.OperationalInsights/workspaces/workspacevxfjfmeby4z7w"
# }

# import {
#   to = azurerm_application_insights.uks_sreagent
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg/providers/Microsoft.Insights/components/uks-sreagent-1-9ea6b9b1-8dbe-app-insights"
# }

# import {
#   to = azurerm_container_app.github_mcp
#   id = "/subscriptions/0433d2b6-3aa6-4751-95d8-ad50c815ede0/resourceGroups/uks-sreagent-rsg/providers/Microsoft.App/containerApps/github-mcp-app"
# }

# // Removed import for azapi_resource.uks_sreagent_1 because the azapi
# // provider's ImportState method does not return state for
# // Microsoft.App/agents (causes "Missing Resource Import State"). The
# // agent will be referenced by `local.agent_resource_id` instead.
