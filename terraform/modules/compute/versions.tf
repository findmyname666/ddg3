terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.59"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}
