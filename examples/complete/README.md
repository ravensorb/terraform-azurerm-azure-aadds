# Azure Active Directory Domain Services Terraform module

Terraform module to create complete Azure Active Directory Domain Services Instance.

## Module Usage

```hcl
# Azurerm Provider configuration
provider "azurerm" {
  features {}
}

module "azure-aadds" {
  source  = "ravensorb/azure-aadds/azurerm"
  version = "1.0.0"

  # A prefix to use for all resouyrces created (if left blank, the resource group name will be used)
  resource_prefix     = "shared-eastus2"

  # By default, this module will create a resource group, proivde the name here
  # to use an existing resource group, specify the existing resource group name, 
  # and set the argument to `create_resource_group = false`. Location will be same as existing RG. 
  resource_group_name = "shared-eastus2-rg-aaddss"
  
  # Location to deploy into
  location            = "eastus2"

  # Networking Settings
  # If create_virtual_network = false then the vnet specified needs to exist
  create_virtual_network              = true
  # If create_virtual_network = true then the vnet name will be automatically set
  #virtual_network_name                = ""
  # If this is left blank it will use the default resource group
  # virtual_network_resource_group_name = ""
  # Network space to use when creating the vnet
  virtual_network_address_space       = [ "10.100.0.0/16" ]

  # If create_virtual_network = false then the snet specified needs to exist
  create_subnet   = true
  # If create_subnet = true then the snet name will be automatically set
  #subnet_name     = ""
  # Network prefix to use when creating the snet
  subnet_prefixes = [ "10.100.0.0/24"]

  # The domain name to use when creating the DC.  Note: It is recommended that this has the potential to be a "routable" domain name
  domain_name = "aadds.domain.com"
  # Indicates the AADDS SKU to use 
  sku = "Standard"

  # Domain admin upn must be a valid upn in the aad 
  domain_admin_upn      = "" 
  # Password to use for domain admin that is created. Note: A random password will be generated if this is left blank.
  domain_admin_password = ""

  # Notification Settings
  notifications = { 
    additional_recipients = [ "someone@somewhere.com", "someoneelse@someplaceelse.com" ]
    dc_admins      = true
    global_admins  = true
  }

  # Security Settings
  security = {
    sync_kerberos_passwords = true
    sync_ntlm_passwords     = true
    sync_on_prem_passwords  = true
  }

  # Adding TAG's to your Azure resources (Required)
  tags = {
    CreatedBy   = "Shawn Anderson"
    CreatedOn   = "2022/05/20"
    CostCenter  = "IT"
    Environment = "PROD"
    Critical    = "YES"
    Location    = "eastus2"
    Solution    = "AADDS"
    ServiceClass = "Gold"
  }
}
```

## Terraform Usage

To run this example you need to execute following Terraform commands

```hcl
terraform init
terraform plan
terraform apply

```

Run `terraform destroy` when you don't need these resources.

## Outputs

Name | Description
---- | -----------
`resource_group_name`|The name of the resource group in which resources are created
`resource_group_id`|The id of the resource group in which resources are created
`resource_group_location`|The location of the resource group in which resources are created
`virtual_network_name`|The name of the virtual network
`virtual_network_id`|The id of the virtual network
`subnet_id`|The name of the subnet that was used/created
`subnet_name`|The name of the storage account that was used/created
`domain_admin_upn`|The upn of the domain admin created
`domain_admin_password`|The password for the domain admin created