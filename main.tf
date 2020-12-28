# Configure the Microsoft Azure Provider
provider "azurerm" {
    features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "terraformgroup" {
    name     = "ResourceGroup"
    location = "eastus"

    tags = {
        environment = "Terraform Docker"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "terraformnetwork" {
    name                = "Vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.terraformgroup.name

    tags = {
        environment = "Terraform Docker"
    }
}

# Create subnet
resource "azurerm_subnet" "terraformsubnet" {
    name                 = "Subnet"
    resource_group_name  = azurerm_resource_group.terraformgroup.name
    virtual_network_name = azurerm_virtual_network.terraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "terraformpublicip" {
    name                         = "PublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.terraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Docker"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraformnsg" {
    name                = "NetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.terraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Docker"
    }
}

# Create network interface
resource "azurerm_network_interface" "terraformnic" {
    name                      = "NIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.terraformgroup.name

    ip_configuration {
        name                          = "NicConfiguration"
        subnet_id                     = azurerm_subnet.terraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.terraformpublicip.id
    }

    tags = {
        environment = "Terraform Docker"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.terraformnic.id
    network_security_group_id = azurerm_network_security_group.terraformnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.terraformgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.terraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Docker"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "terraformvm" {
    name                  = "VM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.terraformgroup.name
    network_interface_ids = [azurerm_network_interface.terraformnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "OsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "vm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Docker"
    }
}


resource "null_resource" "vm_provisioner" {

  depends_on = [azurerm_public_ip.terraformpublicip, azurerm_linux_virtual_machine.terraformvm]
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip.ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "init.sh"
    destination = "/home/azureuser/init.sh"
  }

  provisioner "remote-exec" {
  
   connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip.ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    inline = [
      "chmod +x /home/azureuser/init.sh",
      "/home/azureuser/init.sh", 
    ]
  }
  
  provisioner "remote-exec" {
  
   connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip.ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    inline = [
      "docker run hello-world",
    ]
  }
}

