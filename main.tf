#---------------------------------
# Local declarations
#---------------------------------
# az ad sp create --id "2565bd9d-da50-47d4-8b85-4c97f669dc36"
# terraform import module.azure-aadds.azurerm_resource_provider_registration.aadds /subscriptions/2cfc6338-ffd7-49af-bc95-4b953575483b/providers/Microsoft.AAD
#---------------------------------
locals { 
  resource_group_name = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
  resource_prefix     = var.resource_prefix == "" ? local.resource_group_name : var.resource_prefix
  location            = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)

  timeout_create  = "240m"
  timeout_update  = "240m"
  timeout_delete  = "240m"
  timeout_read    = "15m"
}

#---------------------------------------------------------
# Resource Group Creation or selection - Default is "true"
#----------------------------------------------------------
data "azurerm_resource_group" "rgrp" {
  count = var.create_resource_group == false ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "rg" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
  location = var.location
  tags     = merge({ "ResourceName" = "${var.resource_group_name}" }, var.tags, )

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }
}

#-------------------------------------
# Networking
#-------------------------------------

# VNET
data "azurerm_virtual_network" "vnet" {
  count                 = var.create_virtual_network ? 0 : 1
  name                  = var.virtual_network_name
  resource_group_name   = var.virtual_network_resource_group_name == "" ? var.resource_group_name : var.virtual_network_resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  count                 = var.create_virtual_network ? 1 : 0
  name                  = "${local.resource_prefix}-aadds-vnet"
  location              = local.location
  resource_group_name   = var.virtual_network_resource_group_name == "" ? var.resource_group_name : var.virtual_network_resource_group_name
  address_space         = var.virtual_network_address_space

  tags                = merge({ "ResourceName" = "${local.resource_prefix}-aadds-vnet" }, var.tags, )

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }
}

# Subnet
data "azurerm_subnet" "snet" {
  count                 = var.create_subnet ? 0 : 1
  name                  = var.subnet_name
  resource_group_name   = var.virtual_network_resource_group_name == null ? var.resource_group_name : var.virtual_network_resource_group_name
  virtual_network_name  = var.create_virtual_network ? "${local.resource_prefix}-aadds-vnet" : var.virtual_network_name
}

resource "azurerm_subnet" "snet" {
  count                 = var.create_subnet ? 1 : 0
  name                  = "${local.resource_prefix}-aadds-snet"
  resource_group_name   = local.resource_group_name
  virtual_network_name  = var.create_virtual_network ? "${local.resource_prefix}-aadds-vnet" : var.virtual_network_name  
  address_prefixes      = var.subnet_prefixes

  depends_on = [
    azurerm_virtual_network.vnet,
    data.azurerm_virtual_network.vnet
  ]

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }

}

# Network Security Groups

resource "azurerm_network_security_group" "aadds" {
  name                = "${local.resource_prefix}-aadds-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name

  tags                = merge({ "ResourceName" = "${local.resource_prefix}-aadds-nsg" }, var.tags, )

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }

  # Allow the Azure platform to monitor, manage, and update the managed domain
  # See https://docs.microsoft.com/en-us/azure/active-directory-domain-services/alert-nsg#inbound-security-rules
  security_rule {
    name                       = "AllowRD"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "CorpNetSaw"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowPSRemoting"
    priority                   = 301
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "AzureActiveDirectoryDomainServices"
    destination_address_prefix = "*"
  }

  # Restrict inbound LDAPS access to specific IP addresses to protect the managed domain from brute force attacks.
  # See https://docs.microsoft.com/en-us/azure/active-directory-domain-services/alert-ldaps#resolution
  # See https://docs.microsoft.com/en-us/azure/active-directory-domain-services/tutorial-configure-ldaps#lock-down-secure-ldap-access-over-the-internet
  # security_rule {
  #   name                       = "AllowLDAPS"
  #   priority                   = 401
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "636"
  #   source_address_prefix      = "<Authorized LDAPS IPs>"
  #   destination_address_prefix = "*"
  # }
}

resource "azurerm_subnet_network_security_group_association" "aadds" {
  subnet_id                 = element(coalescelist(azurerm_subnet.snet.*.id, data.azurerm_subnet.snet.*.id, [""]), 0) 
  network_security_group_id = azurerm_network_security_group.aadds.id

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }

}

#-------------------------------------
# Security
#-------------------------------------

# Service Principal for Domain Controller Services published application
# In public Azure, the ID is 2565bd9d-da50-47d4-8b85-4c97f669dc36.
data "azuread_service_principal" "aadds" {
  application_id = "2565bd9d-da50-47d4-8b85-4c97f669dc36"  
}

# Microsoft.AAD Provider Registration

resource "azurerm_resource_provider_registration" "aadds" {
  name = "Microsoft.AAD"

  lifecycle {
    create_before_destroy = true
  }
}

# AADDS DC Admin Group and User
resource "random_password" "dc_admin" {
  length = 64
}

data "azuread_user" "dc_admin" {
  count = var.create_domain_admin ? 0 : 1
  user_principal_name = var.domain_admin_upn
}

resource "azuread_user" "dc_admin" {  
  count = var.create_domain_admin ? 1 : 0
  user_principal_name = var.domain_admin_upn
  display_name        = "AADDS DC Administrator"
  password            = var.domain_admin_password != "" ? var.domain_admin_password : random_password.dc_admin.result

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }
}

resource "azuread_group" "dc_admins" {
  count             = var.create_domain_group ? 1 : 0
  display_name      = "AAD DC Administrators"
  description       = "AADDS Administrators"
  members           = [ element(coalescelist(azuread_user.dc_admin.*.object_id, data.azuread_user.dc_admin.*.object_id, [""]), 0)  ]
  security_enabled  = true

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }
}

data "azuread_group" "dc_admins" {
  count         = var.create_domain_group ? 0 : 1
  display_name  = "AAD DC Administrators"
}

resource "azuread_group_member" "dc_admins" {
  count             = var.create_domain_group ? 0 : 1
  group_object_id   = element(coalescelist(azuread_group.dc_admins.*.object_id, data.azuread_group.dc_admins.*.object_id, [""]), 0)
  member_object_id  = element(coalescelist(azuread_user.dc_admin.*.principal_id, data.azuread_user.dc_admin.*.principal_id, [""]), 0)
}

#-------------------------------------
# AADDS Managed Domain
#-------------------------------------

resource "azurerm_active_directory_domain_service" "aadds" {
  name                = "${local.resource_prefix}-aadds"
  location            = local.location
  resource_group_name = local.resource_group_name

  tags                = merge({ "ResourceName" = "${local.resource_prefix}-aadds" }, var.tags, )

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }

  domain_name = var.domain_name
  sku         = var.sku

  initial_replica_set {
    subnet_id = element(coalescelist(azurerm_subnet.snet.*.id, data.azurerm_subnet.snet.*.id, [""]), 0) 
  }

  notifications {
    additional_recipients = var.notifications.additional_recipients
    notify_dc_admins      = var.notifications.dc_admins
    notify_global_admins  = var.notifications.global_admins    
  }

  security {
    sync_kerberos_passwords = var.security.sync_kerberos_passwords
    sync_ntlm_passwords     = var.security.sync_ntlm_passwords
    sync_on_prem_passwords  = var.security.sync_on_prem_passwords
  }

  depends_on = [
    data.azuread_service_principal.aadds,
    azurerm_resource_provider_registration.aadds,
    azurerm_subnet_network_security_group_association.aadds,
  ]
}