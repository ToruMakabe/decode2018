resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}-${var.location}-rg"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                      = "subnet"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  address_prefix            = "10.0.1.0/24"
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg"
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

resource "azurerm_public_ip" "pip-vmss" {
  name                         = "pip-vmss"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  location                     = "${azurerm_resource_group.rg.location}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${var.scaleset_name}"

  sku = "Standard"
}

resource "azurerm_public_ip" "pip-jb" {
  name                         = "pip-jb"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  location                     = "${azurerm_resource_group.rg.location}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${var.jumpbox_name_label}"

  sku = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "lb"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"

  frontend_ip_configuration {
    name                 = "fipConf"
    public_ip_address_id = "${azurerm_public_ip.pip-vmss.id}"
  }

  sku = "Standard"
}

resource "azurerm_lb_backend_address_pool" "bePool" {
  name                = "bePool"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"
}

resource "azurerm_lb_rule" "lbRule" {
  name                           = "lbRule"
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "fipConf"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bePool.id}"
  probe_id                       = "${azurerm_lb_probe.http-probe.id}"
}

resource "azurerm_lb_probe" "http-probe" {
  name                = "http-probe"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"
  port                = 80
}

resource "azurerm_network_interface" "vmnic" {
  name                = "vmnic"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "vmnicconf"
    subnet_id                     = "${azurerm_subnet.subnet.id}"
    public_ip_address_id          = "${azurerm_public_ip.pip-jb.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_virtual_machine" "vm-jb" {
  name                  = "${var.jumpbox_name_label}-${var.location}"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.vmnic.id}"]
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
    computer_name  = "${var.jumpbox_name_label}-${var.location}"
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

resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = "${var.scaleset_name}-${var.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  upgrade_policy_mode = "Manual"
  overprovision       = true

  sku {
    name     = "Standard_F1s"
    tier     = "Standard"
    capacity = 3
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
    computer_name_prefix = "${var.scaleset_name}-${var.location}"
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
    name    = "tfnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "demoIPConfiguration"
      subnet_id                              = "${azurerm_subnet.subnet.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bePool.id}"]
    }
  }

  zones = [1, 2, 3]
}
