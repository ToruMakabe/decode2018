resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}-rg"
  location = "${var.location01}"
}

resource "azurerm_virtual_network" "vnet01" {
  name                = "vnet01"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${var.location01}"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "vnet02" {
  name                = "vnet02"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${var.location02}"
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_virtual_network_peering" "vnetpeer01" {
  name                         = "peer1to2"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  virtual_network_name         = "${azurerm_virtual_network.vnet01.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.vnet02.id}"
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "vnetpeer02" {
  name                         = "peer2to1"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  virtual_network_name         = "${azurerm_virtual_network.vnet02.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.vnet01.id}"
  allow_virtual_network_access = true
}

resource "azurerm_subnet" "subnet01" {
  name                      = "subnet01"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet01.name}"
  address_prefix            = "10.0.1.0/24"
  network_security_group_id = "${azurerm_network_security_group.nsg01.id}"
}

resource "azurerm_subnet" "subnet02" {
  name                      = "subnet02"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet02.name}"
  address_prefix            = "10.1.1.0/24"
  network_security_group_id = "${azurerm_network_security_group.nsg02.id}"
}

resource "azurerm_network_security_group" "nsg01" {
  name                = "nsg01"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${var.location01}"

  security_rule = [
    {
      name                       = "allow_ssh"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
  ]
}

resource "azurerm_network_security_group" "nsg02" {
  name                = "nsg02"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${var.location02}"

  security_rule = [
    {
      name                       = "allow_ssh"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
  ]
}

resource "azurerm_public_ip" "pip01" {
  name                         = "pip01"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  location                     = "${var.location01}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "${var.jumpbox_name_label}01-${count.index}"
  count                        = 1
  sku                          = "Basic"
}

resource "azurerm_public_ip" "pip02" {
  name                         = "pip02"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  location                     = "${var.location02}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "${var.jumpbox_name_label}02"
  sku                          = "Basic"
}

resource "azurerm_network_interface" "vmnic01" {
  name                          = "vmnic01-${count.index}"
  location                      = "${var.location01}"
  resource_group_name           = "${azurerm_resource_group.rg.name}"
  enable_accelerated_networking = true
  count                         = 1

  ip_configuration {
    name                          = "vmnicconf01-${count.index}"
    subnet_id                     = "${azurerm_subnet.subnet01.id}"
    public_ip_address_id          = "${element(azurerm_public_ip.pip01.*.id, count.index)}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_network_interface" "vmnic02" {
  name                          = "vmnic02"
  location                      = "${var.location02}"
  resource_group_name           = "${azurerm_resource_group.rg.name}"
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "vmnicconf02"
    subnet_id                     = "${azurerm_subnet.subnet02.id}"
    public_ip_address_id          = "${azurerm_public_ip.pip02.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_virtual_machine" "vm01" {
  name                  = "vm01-${count.index}"
  location              = "${var.location01}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${element(azurerm_network_interface.vmnic01.*.id, count.index)}"]
  vm_size               = "Standard_D64_v3"
  count                 = 1

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk01"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vm01"
    admin_username = "${var.admin_username}"
    admin_password = ""
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }
  }
}

resource "azurerm_virtual_machine" "vm02" {
  name                  = "vm02"
  location              = "${var.location02}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.vmnic02.id}"]
  vm_size               = "Standard_D64_v3"

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk02"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vm02"
    admin_username = "${var.admin_username}"
    admin_password = ""
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }
  }
}

resource "azurerm_virtual_machine_extension" "ext01" {
  name                 = "ext01-${count.index}"
  location             = "${var.location01}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_machine_name = "${element(azurerm_virtual_machine.vm01.*.name, count.index)}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  count                = 1

  settings = <<SETTINGS
    {
        "commandToExecute": "apt-get -y install build-essential && apt-get -y install git && git clone https://github.com/Microsoft/ntttcp-for-linux && cd ntttcp-for-linux/src && make && make install"
    }
SETTINGS
}

resource "azurerm_virtual_machine_extension" "ext02" {
  name                 = "ext02"
  location             = "${var.location02}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_machine_name = "${azurerm_virtual_machine.vm02.name}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "apt-get -y install build-essential && apt-get -y install git && git clone https://github.com/Microsoft/ntttcp-for-linux && cd ntttcp-for-linux/src && make && make install"
    }
SETTINGS
}
