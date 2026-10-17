### AKS UAMI ###

resource "azurerm_user_assigned_identity" "uks_aks_identity" {
  name                = "uks-aks-identity"
  location            = azurerm_resource_group.uks_aks_rsg.location
  resource_group_name = azurerm_resource_group.uks_aks_rsg.name
  tags                = var.tags
}

# Private cluster with a custom private DNS zone: AKS creates the zone's VNet link
# and joins nodes / load balancers to the subnet, so it needs Network Contributor
# on the VNet (in uks-vnet-rsg) plus Private DNS Zone Contributor on the zone.
resource "azurerm_role_assignment" "uks_aks_vnet_network_contributor" {
  scope                = azurerm_virtual_network.uks_vnet_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.uks_aks_identity.principal_id
}

resource "azurerm_role_assignment" "uks_aks_private_dns_contributor" {
  scope                = azurerm_private_dns_zone.privatelink_azmk8s_io.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.uks_aks_identity.principal_id
}

### AKS CLUSTER ###

resource "azurerm_kubernetes_cluster" "uks_aks_aks" {
  name                = "uks-aks-aks"
  location            = azurerm_resource_group.uks_aks_rsg.location
  resource_group_name = azurerm_resource_group.uks_aks_rsg.name
  dns_prefix          = "uks-aks"
  sku_tier            = "Free"
  tags                = var.tags

  # API server is only reachable via a private endpoint in the AKS subnet.
  private_cluster_enabled             = true
  private_dns_zone_id                 = azurerm_private_dns_zone.privatelink_azmk8s_io.id
  private_cluster_public_fqdn_enabled = false

  # Entra ID authentication + Azure RBAC for Kubernetes authorization; no local
  # (certificate) accounts, so all kubectl access is governed by role assignments.
  local_account_disabled = true

  azure_active_directory_role_based_access_control {
    tenant_id          = local.tenant_id
    azure_rbac_enabled = true
  }

  depends_on = [
    azurerm_role_assignment.uks_aks_vnet_network_contributor,
    azurerm_role_assignment.uks_aks_private_dns_contributor,
  ]

  default_node_pool {
    name            = "system"
    vm_size         = var.aks_node_vm_size
    node_count      = var.aks_node_count
    vnet_subnet_id  = azurerm_subnet.aks.id
    os_disk_size_gb = 30

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uks_aks_identity.id]
  }

  # Service/pod ranges must not overlap the 10.0.0.0/24 VNet.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.100.0.0/16"
    dns_service_ip      = "10.100.0.10"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }
}

### AKS ROLE ASSIGNMENTS ###

# Whoever runs terraform deploys the test workload via `az aks command invoke`.
resource "azurerm_role_assignment" "uks_aks_deployer_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.uks_aks_aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.uks_aks_aks.name
}

output "aks_get_credentials_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.uks_aks_rsg.name} --name ${azurerm_kubernetes_cluster.uks_aks_aks.name}"
}
