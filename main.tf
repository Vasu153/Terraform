# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
subscription_id ="7f5211fb-d31b-41c1-b234-db7f0799cf87"

}
terraform {
  backend "azurerm" {
    storage_account_name = "terraformstorageaccntvas"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"

    # rather than defining this inline, the Access Key can also be sourced
    # from an Environment Variable - more information is available below.
    access_key = "WbtOVNzlJAq56qC+SiUCDNp63ROJB4oioQi7e1Wo9pda7JFDIhG+7NCDYqNVFvfQ4CbSZ2znMFA1+AStD2J9DQ=="
    
  }
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "Terraform_Test_Rg"
  location = "West Europe"
}


# Create a Virtual Network

resource "azurerm_virtual_network" "Vnet" {
  name                = "Terrafom_Test_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "Subnet" {
  name                 = "Terrafom_Test_Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.Vnet.name
  address_prefixes       = ["10.0.1.0/24"]
}


resource "azurerm_nat_gateway" "Nat_Gat" {
  name                = "Terrafom_Test_natgateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_nat_gateway_association" "Sub_Nat_Gat" {
  subnet_id      = azurerm_subnet.Subnet.id
  nat_gateway_id = azurerm_nat_gateway.Nat_Gat.id
}

# Create a resource group

resource "azurerm_resource_group" "rg1" {
  name     = "${var.rgname}"
  location = "${var.rglocation}"
}

# Create a Virtual Network
resource "azurerm_virtual_network" "vnet1" {
  name                = "${var.prefix}-10"
  resource_group_name = "${azurerm_resource_group.rg1.name}"
  location            = "${azurerm_resource_group.rg1.location}"
  address_space       = ["${var.vnet_cidr_prefix}"]
}
resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  virtual_network_name = "${azurerm_virtual_network.vnet1.name}"
  resource_group_name  = "${azurerm_resource_group.rg1.name}"
  address_prefixes     = ["${var.subnet1_cidr_prefix}"]
}

resource "azurerm_network_security_group" "nsg1" {
  name                = "${var.prefix}-nsg1"
  resource_group_name = "${azurerm_resource_group.rg1.name}"
  location            = "${azurerm_resource_group.rg1.location}"
}

# NOTE: this allows RDP from any network
resource "azurerm_network_security_rule" "rdp" {
  name                        = "rdp"
  resource_group_name         = "${azurerm_resource_group.rg1.name}"
  network_security_group_name = "${azurerm_network_security_group.nsg1.name}"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnet_assoc" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg1.id
}

resource "azurerm_network_interface" "nic1" {
  name                = "${var.prefix}-nic"
  resource_group_name = azurerm_resource_group.rg1.name
  location            = azurerm_resource_group.rg1.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "main" {
  name                            = "${var.prefix}-vmt01"
  resource_group_name             = azurerm_resource_group.rg1.name
  location                        = azurerm_resource_group.rg1.location
  size                            = "Standard_B1s"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  network_interface_ids = [ azurerm_network_interface.nic1.id ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2012-R2-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}
