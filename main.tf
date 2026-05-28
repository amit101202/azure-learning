# ============================================================
# Secure Azure Landing Zone — Project 1
# Task 2: Provider configuration + resource group
# ============================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# The container that holds everything in this project
resource "azurerm_resource_group" "lab" {
  name     = "rg-landingzone-lab"
  location = "Australia East"

  tags = {
    project     = "secure-landing-zone"
    environment = "lab"
    managed_by  = "terraform"
  }
}
# ============================================================
# Task 4: Virtual network + segmented subnets
# ============================================================

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-landingzone"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.10.0.0/16"]

  tags = {
    project     = "secure-landing-zone"
    environment = "lab"
    managed_by  = "terraform"
  }
}

# Where workloads (VMs, apps) live
resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# For Azure Bastion — name MUST be exactly "AzureBastionSubnet"
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/26"]
}

# For Azure Firewall — name MUST be exactly "AzureFirewallSubnet"
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.3.0/26"]
}
# ============================================================
# Task 5: Network Security Group — deny-by-default baseline
# ============================================================

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-workload"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  tags = {
    project     = "secure-landing-zone"
    environment = "lab"
    managed_by  = "terraform"
  }
}

# Explicit deny-all inbound — the deny-by-default baseline.
# Low priority (4096 = lowest) so any future ALLOW rule (lower number)
# is evaluated first. This makes "deny unless explicitly allowed" visible.
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload.name
}
# ============================================================
# Task 6: Associate the NSG with the workload subnet
# Without this, the NSG rules enforce nothing.
# ============================================================

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
