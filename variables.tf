variable "create_resource_group" {
  description = "Whether to create resource group and use it for all resources"
  default     = true
}

variable "resource_group_name" {
  description = "A container that holds related resources for an Azure solution"
  default     = "rg-aadds"
}

variable "location" {
  description = "The location/region to keep all your network resources. To get the list of all locations with table format from azure cli, run 'az account list-locations -o table'"
  default     = "eastus2"
}

variable "resource_prefix" {
  description = "(Optional) Prefix to use for all resoruces created (Defaults to resource_group_name)"
  default     = ""
}

variable "create_virtual_network" {
  description = "Whether to create virtual network and use it for all networking resources"
  default     = true
}

variable "virtual_network_name" {
    description = "(Optional) Indicates the name of vnet"
    default     = ""
}

variable "virtual_network_resource_group_name" {
    description = "(Optional) Indicates the name of resource group that contains the vnet"
    default     = ""
}

variable "virtual_network_address_space" {
  description = "Address Speace list to use for the virtual network"
  default     = [ "10.100.100.0/16" ]
}

variable "create_subnet" {
  description = "Whether to create subnet and use it for all networking resources"
  default     = true
}

variable "subnet_name" {
    description = "(Optional) Indicates the name of subnet"
    default     = ""
}

variable "subnet_prefixes" {
  description = "(Optional) List of subnet prefixes"
  default     = [ "10.100.100.0/24 "]
}

variable "create_domain_controller_services_service_principal" {
  description = "Indicates if the standard Domain Controler Services Service Principal should be created in the current AAD env"
  default     = false
}

variable "domain_name" {
  description = "(Requrired) Domain name to use when creating AADS"
  default     = null
}

variable "create_domain_admin" {
  description = "(Optional) Indicate if the AADDS admin user should be created"
  default     = true
}

variable "domain_admin_upn" {
  description = "(Required) The domain admin user name"
  default     = "aadds-admin"
}

variable "domain_admin_password" {
  description = "(Optional) The password to use for the new DC admin (a random one will be created if this is left blank)"
  default     = ""
}

variable "create_domain_group" {
  description = "(Optional) Indicate if the AADDS admin group should be created"
  default     = true
}

variable "sku" {
  description   = "SKU to use for AADS"  
  default       = "Standard"
}

variable "notifications" {
  description = "Notification Settings"
  type        = object({ additional_recipients = list(string), dc_admins = bool, global_admins = bool})
  default = {
    additional_recipients = [ ]
    dc_admins      = true
    global_admins  = true
  }
}

variable "security" {
  description = "Security settings"
  type        = object({ sync_kerberos_passwords = bool, sync_ntlm_passwords = bool, sync_on_prem_passwords = bool})
  default = {
    sync_kerberos_passwords = true
    sync_ntlm_passwords     = true
    sync_on_prem_passwords  = true
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
