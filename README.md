# Azure Active Directory Domain Services Terraform module

Azure Active Directory Domain Services (Azure AD DS) provides managed domain services such as domain join, group policy, lightweight directory access protocol (LDAP), and Kerberos/NTLM authentication. You use these domain services without the need to deploy, manage, and patch domain controllers (DCs) in the cloud.

An Azure AD DS managed domain lets you run legacy applications in the cloud that can't use modern authentication methods, or where you don't want directory lookups to always go back to an on-premises AD DS environment. You can lift and shift those legacy applications from your on-premises environment into a managed domain, without needing to manage the AD DS environment in the cloud.

Azure AD DS integrates with your existing Azure AD tenant. This integration lets users sign in to services and applications connected to the managed domain using their existing credentials. You can also use existing groups and user accounts to secure access to resources. These features provide a smoother lift-and-shift of on-premises resources to Azure.

## Module Usage

```hcl
# Azurerm Provider configuration
provider "azurerm" {
  features {}
}

module "azure-aadds" {
  source  = "ravensorb/azure-aadds/azurerm"
  version = "1.0.1"

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

## Pre-requisites 
Note: these are only required if you are planning to limit network access to specific subnets

Account that is executing this module MUST have permission to create service principals if you need the AADDS service principals automatically regiered 

Use the following article for reference:
https://docs.microsoft.com/en-us/azure/active-directory-domain-services/powershell-create-instance

```powershell
Install-Module -Name Az.Resources

if ($null -eq (Get-AzADServicePrincipal -ApplicationId "2565bd9d-da50-47d4-8b85-4c97f669dc36" -ErrorAction SilentlyContainer)) { New-AzADServicePrincipal -ApplicationId "2565bd9d-da50-47d4-8b85-4c97f669dc36" }

Register-AzResourceProvider -ProviderNamespace Microsoft.AAD
```


### Virtual network / Resource Group Name

You can create a new virtual network in the portal during this process, or use an existing virtual network to limit access to the service. If you are using an existing virtual network, make sure the existing virtual network has a subnet created as well

### Subnet

The subnet will be used to limit access to Azure File Sync.  This is useful in a traditional hub and spoke model deployment


## Requirements

Name | Version
-----|--------
terraform | >= 0.13
azurerm | >= 2.59.0

## Providers

| Name | Version |
|------|---------|
azurerm |>= 2.59.0

## Inputs

Name | Description | Type | Default
---- | ----------- | ---- | -------
`create_resource_group`|Whether to create resource group and use it for all resources|`bool`|`true`
`resource_group_name`|A container that holds related resources for an Azure solution|`string`|`rg-aadds`
`location`|The location/region to keep all your network resources. To get the list of all locations with table format from azure cli, run 'az account list-locations -o table'|`string`|`eastus2`
`resource_prefix`|(Optional) Prefix to use for all resoruces created (Defaults to resource_group_name)|`string`|``
`create_virtual_network`|Whether to create virtual network and use it for all networking resources|`bool`|`true`
`virtual_network_name`|(Optional) Indicates the name of vnet|`string`|``
`virtual_network_resource_group_name`|(Optional) Indicates the name of resource group that contains the vnet to limit access to (Reqired if limited access)|`string`|``
`virtual_network_address_space`|Address Speace list to use for the virtual network|`list(string)`|`[ "10.100.0.0/16" ]`
`create_subnet`|Whether to create subnet and use it for all networking resources|`bool`|`true`
`subnet_name`|(Optional) Indicates the name of subnet|`string`|``
`subnet_prefixes`|(Optional) List of subnet prefixes|`list(string)`|`[ "10.100.0.0/24"]`
`domain_name`|(Requrired) Domain name to use when creating AADS|`string`|``
`domain_admin_password`|(Optional) The password to use for the new DC admin (a random one will be created if this is left blank)|`string`|`""`
`sku`|SKU to use for AADS|`string`|`Standard`
`network_security_group_name`|(Optional) Name of existing network security group to add nsg rules (leave blank to create a new one)|`string`|
`network_security_group_resource_group_name`|(Optional) Name of resource group that contains the existing network security group (defaults to the resource group for this module)|`string`|
`notifications`|Notification Settings|`object`|`{}`
`security`|Security settings|`object`|`{}`
`tags`|A map of tags to add to all resources|`map(string)`|{}

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

## Authors

Originally created by [Shawn Anderson](mailto:sanderson@eye-catcher.com)

## Other resources

* [Azure File Sync](https://docs.microsoft.com/en-us/azure/storage/file-sync/file-sync-introduction)
* [Terraform AzureRM Provider Documentation](https://www.terraform.io/docs/providers/azurerm/index.html)
