terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.59"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }
  }
}
