terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # Only needed to process the `removed` blocks in aks_test_app.tf; drop both
    # once those resources are gone from state.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.36, < 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azapi" {}
