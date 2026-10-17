### AKS TEST WORKLOAD ###

# The API server is private, so terraform (running outside the VNet) can't use the
# kubernetes provider. The manifest is applied through ARM with `az aks command
# invoke` instead, re-running whenever the cluster or manifest changes.
resource "terraform_data" "aks_test_app" {
  triggers_replace = [
    azurerm_kubernetes_cluster.uks_aks_aks.id,
    filesha256("${path.module}/k8s/aks-test-app.yaml"),
  ]

  depends_on = [
    azurerm_role_assignment.uks_aks_deployer_cluster_admin,
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/k8s"
    interpreter = ["pwsh", "-NoProfile", "-Command"]
    # Retries cover Azure RBAC propagation for the new cluster admin assignment.
    command = <<-EOT
      for ($i = 1; $i -le 10; $i++) {
        $r = az aks command invoke --resource-group ${azurerm_resource_group.uks_aks_rsg.name} --name ${azurerm_kubernetes_cluster.uks_aks_aks.name} --command "kubectl apply -f aks-test-app.yaml" --file aks-test-app.yaml -o json | ConvertFrom-Json
        if ($r) { Write-Output $r.logs }
        if ($r -and $r.exitCode -eq 0) { exit 0 }
        Write-Output "Attempt $i failed, retrying in 30s..."
        Start-Sleep -Seconds 30
      }
      exit 1
    EOT
  }
}

output "aks_test_app_url" {
  value = "http://10.0.0.126"
}

# Previously managed with the kubernetes provider against the public API server.
# They are destroyed with the old cluster, so just drop them from state.
removed {
  from = kubernetes_service_v1.aks_test_app
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_deployment_v1.aks_test_app
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_namespace_v1.aks_test_app
  lifecycle {
    destroy = false
  }
}
