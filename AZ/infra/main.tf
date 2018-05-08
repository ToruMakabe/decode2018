resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}"
  location = "Central US"
}

resource "azurerm_virtual_network" "vnet01" {
  name                = "vnet01"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet01" {
  name                      = "subnet01"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet01.name}"
  address_prefix            = "10.0.2.0/24"
  network_security_group_id = "${azurerm_network_security_group.nsg01.id}"
}

resource "azurerm_network_security_group" "nsg01" {
  name                = "nsg01"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"

  security_rule = [
    {
      name                       = "allow_http"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "allow_ssh"
      priority                   = 101
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
  location                     = "${azurerm_resource_group.rg.location}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${var.scaleset_name}"

  sku = "Standard"
}

resource "azurerm_public_ip" "pip02" {
  name                         = "pip02"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  location                     = "${azurerm_resource_group.rg.location}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${var.jumpbox_name}"

  sku = "Standard"
}

resource "azurerm_lb" "lb01" {
  name                = "lb01"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"

  frontend_ip_configuration {
    name                 = "fipConf01"
    public_ip_address_id = "${azurerm_public_ip.pip01.id}"
  }

  sku = "Standard"
}

resource "azurerm_lb_backend_address_pool" "bePool01" {
  name                = "bePool01"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb01.id}"
}

resource "azurerm_lb_rule" "lbRule01" {
  name                           = "lbRule01"
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb01.id}"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "fipConf01"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bePool01.id}"
  probe_id                       = "${azurerm_lb_probe.http-probe.id}"
}

resource "azurerm_lb_probe" "http-probe" {
  name                = "http-probe"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb01.id}"
  port                = 80
}

resource "azurerm_network_interface" "vmnic01" {
  name                = "vmnic01"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "vmnicconf01"
    subnet_id                     = "${azurerm_subnet.subnet01.id}"
    public_ip_address_id          = "${azurerm_public_ip.pip02.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_virtual_machine" "vm01" {
  name                  = "vm01"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.vmnic01.id}"]
  vm_size               = "Standard_B1s"

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "CoreOS"
    offer     = "CoreOS"
    sku       = "stable"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk01"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "jumpboxvm"
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

  zones = [1]
}

resource "azurerm_virtual_machine_scale_set" "vmss01" {
  name                = "${var.scaleset_name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_D2s_v3"
    tier     = "Standard"
    capacity = 4
  }

  storage_profile_image_reference {
    publisher = "CoreOS"
    offer     = "CoreOS"
    sku       = "Stable"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "vmss"
    admin_username       = "${var.admin_username}"
    admin_password       = ""
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }
  }

  extension {
    name                 = "CustomScriptExtension"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    settings = <<SETTINGS
    {
        "commandToExecute": "docker run --name getazmeta -d -p 80:80 -t torumakabe/getazmeta:v0.0.4"
    }
SETTINGS
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "demoIPConfiguration"
      subnet_id                              = "${azurerm_subnet.subnet01.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bePool01.id}"]
    }
  }

  zones = [1, 2, 3]
}
