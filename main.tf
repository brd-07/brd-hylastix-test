resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}


############################################ VIRTUAL NETWORK ############################################################
resource "azurerm_virtual_network" "vnet" {
  name                                    = "brd-hylastix-test-vnet"
  address_space                           = ["10.0.0.0/16"]
  location                                = azurerm_resource_group.rg.location
  resource_group_name                     = azurerm_resource_group.rg.name
}
#########################################################################################################################


############################################ VNET SUBNET ################################################################
resource "azurerm_subnet" "subnet" {
  name                                    = "brd-hylastix-test-subnet"
  resource_group_name                     = azurerm_resource_group.rg.name
  virtual_network_name                    = azurerm_virtual_network.vnet.name
  address_prefixes                        = ["10.0.1.0/24"]
}
#########################################################################################################################


############################################ VNET NSG ###################################################################
resource "azurerm_network_security_group" "nsg" {
  name                                    = "brd-hylastix-test-nsg"
  location                                = azurerm_resource_group.rg.location
  resource_group_name                     = azurerm_resource_group.rg.name

  security_rule {
    name                                  = "SSH"
    priority                              = 1001
    direction                             = "Inbound"
    access                                = "Allow"
    protocol                              = "Tcp"
    source_port_range                     = "*"
    destination_port_range                = "22"
    source_address_prefix                 = "*"
    destination_address_prefix            = "*"
  }

  security_rule {
    name                                  = "HTTP"
    priority                              = 1002
    direction                             = "Inbound"
    access                                = "Allow"
    protocol                              = "Tcp"
    source_port_range                     = "*"
    destination_port_range                = "80"
    source_address_prefix                 = "*"
    destination_address_prefix            = "*"
  }

  security_rule {
    name                                  = "Keycloak"
    priority                              = 1003
    direction                             = "Inbound"
    access                                = "Allow"
    protocol                              = "Tcp"
    source_port_range                     = "*"
    destination_port_range                = "8080"
    source_address_prefix                 = "*"
    destination_address_prefix            = "*"
  }
}
#########################################################################################################################


############################################ PUBLIC IP ##################################################################
resource "azurerm_public_ip" "pip" {
  name                                    = "brd-hylastix-test-pip"
  location                                = azurerm_resource_group.rg.location
  resource_group_name                     = azurerm_resource_group.rg.name
  sku                                     = var.pip_sku
  sku_tier                                = "Regional"
  allocation_method                       = "Static"
  ddos_protection_mode                    = "VirtualNetworkInherited"
  zones                                   = []
}
#########################################################################################################################


############################################ NETWORK INTERFACE ##########################################################
resource "azurerm_network_interface" "nic" {
  name                                    = "brd-hylastix-test-nic"
  location                                = azurerm_resource_group.rg.location
  resource_group_name                     = azurerm_resource_group.rg.name

  ip_configuration {
    name                                  = "internal"
    subnet_id                             = azurerm_subnet.subnet.id
    private_ip_address_allocation         = "Dynamic"
    public_ip_address_id                  = azurerm_public_ip.pip.id
  }
}
#########################################################################################################################


############################################ NIC TO NSG ASSOCIATION #####################################################
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id                    = azurerm_network_interface.nic.id
  network_security_group_id               = azurerm_network_security_group.nsg.id
}
#########################################################################################################################


############################################ VIRTUAL MACHINE ############################################################
resource "azurerm_linux_virtual_machine" "vm" {
  name                                    = "brd-hylastix-test-vm"
  resource_group_name                     = azurerm_resource_group.rg.name
  location                                = azurerm_resource_group.rg.location
  size                                    = var.vm_size
  admin_username                          = var.admin_username
  admin_password                          = var.admin_password  # Disable password auth in prod, use SSH keys
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching                               = "ReadWrite"
    storage_account_type                  = "Standard_LRS"
  }

  source_image_reference {
    publisher                             = "Canonical"
    offer                                 = "0001-com-ubuntu-server-jammy"
    sku                                   = "22_04-lts"
    version                               = "latest"
  }
}
#########################################################################################################################