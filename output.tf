output "resource_group_name" {
  description = "The name of the resource group in which resources are created"
  value       = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
}

output "resource_group_id" {
  description = "The id of the resource group in which resources are created"
  value       = element(coalescelist(data.azurerm_resource_group.rgrp.*.id, azurerm_resource_group.rg.*.id, [""]), 0)
}

output "resource_group_location" {
  description = "The location of the resource group in which resources are created"
  value       = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)
}

# Vnet and Subnets
output "virtual_network_name" {
  description = "The name of the virtual network"
  value       = element(concat(azurerm_virtual_network.vnet.*.name, [""]), 0)
}

output "virtual_network_id" {
  description = "The id of the virtual network"
  value       = element(concat(azurerm_virtual_network.vnet.*.id, [""]), 0)
}

output "subnet_id" {
  description = "The name of the subnet that was used/created"
  value       = element(coalescelist(data.azurerm_subnet.snet.*.id, azurerm_subnet.snet.*.id, [""]), 0) 
}

output "subnet_name" {
  description = "The name of the storage account that was used/created"
  value       = element(coalescelist(data.azurerm_subnet.snet.*.name, azurerm_subnet.snet.*.name, [""]), 0) 
}

output "domain_admin_upn" {
  description = "The upn of the domain admin created"
  value       = element(coalescelist(data.azuread_user.dc_admin.*.user_principal_name, azuread_user.dc_admin.*.user_principal_name, [""]), 0)
}

output "domain_admin_password" {
  description = "The password for the domain admin created"
  value       = var.create_domain_admin ? azuread_user.dc_admin.0.password : ""
  sensitive   = true
}
