#---------------------------------
# Local declarations
#---------------------------------
# az ad sp create --id "2565bd9d-da50-47d4-8b85-4c97f669dc36"
# terraform import module.azure-aadds.azurerm_resource_provider_registration.aadds /subscriptions/<subscription id>/providers/Microsoft.AAD
#---------------------------------
locals { 
  resource_prefix     = var.resource_prefix == "" ? var.resource_group_name : var.resource_prefix

  timeout_create  = "240m"
  timeout_update  = "240m"
  timeout_delete  = "240m"
  timeout_read    = "15m"
}

#---------------------------------------------------------
# Resource Group Creation or selection - Default is "true"
#----------------------------------------------------------
data "azurerm_resource_group" "aadds-rg" {
  count = var.create_resource_group == false ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "aadds-rg" {
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
  location              = var.location
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
  resource_group_name   = var.resource_group_name
  virtual_network_name  = var.create_virtual_network ? "${local.resource_prefix}-aadds-vnet" : var.virtual_network_name  
  address_prefixes      = var.subnet_prefixes
  service_endpoints     = [ "Microsoft.AzureActiveDirectory", "Microsoft.Storage" ]

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
data "azurerm_network_security_group" "aadds" {
  count               = var.network_security_group_name != null ? 1 : 0
  name                = var.network_security_group_name
  resource_group_name = var.network_security_group_resource_group_name != null ? var.network_security_group_resource_group_name : var.resource_group_name
}

resource "azurerm_network_security_group" "aadds" {
  count               = var.network_security_group_name != null ? 0 : 1
  name                = "${local.resource_prefix}-aadds-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags                = merge({ "ResourceName" = "${local.resource_prefix}-aadds-nsg" }, var.tags, )

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }
}

# Allow the Azure platform to monitor, manage, and update the managed domain
# See https://docs.microsoft.com/en-us/azure/active-directory-domain-services/alert-nsg#inbound-security-rules
resource "azurerm_network_security_rule" "aadds-nsg-rule-allow-rd" {
  network_security_group_name = element(coalescelist(data.azurerm_network_security_group.aadds.*.name, azurerm_network_security_group.aadds.*.name, [""]), 0)
  resource_group_name         = var.network_security_group_resource_group_name != null ? var.network_security_group_resource_group_name : var.resource_group_name

  name                       = "AllowRD"
  priority                   = 201
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "3389"
  source_address_prefix      = "CorpNetSaw"
  destination_address_prefix = "*"

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }
}

# Allow the Azure platform to monitor, manage, and update the managed domain
# See https://docs.microsoft.com/en-us/azure/active-directory-domain-services/alert-nsg#inbound-security-rules
resource "azurerm_network_security_rule" "aadds-nsg-rule-allow-psremoting" {
  network_security_group_name = element(coalescelist(data.azurerm_network_security_group.aadds.*.name, azurerm_network_security_group.aadds.*.name, [""]), 0)
  resource_group_name         = var.network_security_group_resource_group_name != null ? var.network_security_group_resource_group_name : var.resource_group_name

  name                       = "AllowPSRemoting"
  priority                   = 301
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "5986"
  source_address_prefix      = "AzureActiveDirectoryDomainServices"
  destination_address_prefix = "*"

  timeouts {
    create  = local.timeout_create
    delete  = local.timeout_delete
    read    = local.timeout_read
    update  = local.timeout_update
  }
}

# Restrict inbound LDAPS access to specific IP addresses to protect the managed domain from brute force attacks.
# See https://docs.microsoft.com/en-us/azure/active-directory-domain-services/alert-ldaps#resolution
# See https://docs.microsoft.com/en-us/azure/active-directory-domain-services/tutorial-configure-ldaps#lock-down-secure-ldap-access-over-the-internet
# resource "azurerm_network_security_rule" "aadds-nsg-rule-allow-ldaps" {
#   count                       = 0
#
#   network_security_group_name = element(coalescelist(data.azurerm_network_security_group.aadds.*.name, azurerm_network_security_group.aadds.*.name, [""]), 0)
#   resource_group_name         = var.network_security_group_resource_group_name != null ? var.network_security_group_resource_group_name : var.resource_group_name
#
#   name                        = "AllowLDAPS"
#   priority                    = 401
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_port_range           = "*"
#   destination_port_range      = "636"
#   source_address_prefix       = var.ldap_ips
#   destination_address_prefix  = "*"
# }

resource "azurerm_subnet_network_security_group_association" "aadds" {
  count                     = var.network_security_group_name != null ? 0 : 1
  subnet_id                 = element(coalescelist(azurerm_subnet.snet.*.id, data.azurerm_subnet.snet.*.id, [""]), 0) 
  network_security_group_id = element(coalescelist(data.azurerm_network_security_group.aadds.*.id, azurerm_network_security_group.aadds.*.id, [""]), 0)

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
# In public Azure, the ID is 2565bd9d-da50-47d4-8b85-4c97f669dc36 (Domain Controller Services).
data "azuread_service_principal" "aadds" {
  count           = var.create_domain_controller_services_service_principal ? 0 : 1
  application_id  = "2565bd9d-da50-47d4-8b85-4c97f669dc36"  
  #display_name    = "Domain Controller Services" 
}

resource azuread_service_principal "aadds" {
  count           = var.create_domain_controller_services_service_principal ? 1 : 0  
  application_id  = "2565bd9d-da50-47d4-8b85-4c97f669dc36"  
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
  description       = "Delegated group to administer Azure AD Domain Services"
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
  count             = var.create_domain_group || var.create_domain_admin ? 1 : 0
  group_object_id   = element(coalescelist(azuread_group.dc_admins.*.object_id, data.azuread_group.dc_admins.*.object_id, [""]), 0)
  member_object_id  = element(coalescelist(azuread_user.dc_admin.*.object_id, data.azuread_user.dc_admin.*.object_id, [""]), 0)
}

#-------------------------------------
# AADDS Managed Domain
#-------------------------------------

resource "azurerm_active_directory_domain_service" "aadds" {
  name                = "${local.resource_prefix}-aadds"
  location            = var.location
  resource_group_name = var.resource_group_name

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
    azuread_service_principal.aadds,
    azurerm_resource_provider_registration.aadds,
    azurerm_subnet_network_security_group_association.aadds,
  ]
}