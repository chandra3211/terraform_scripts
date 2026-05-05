# Terraform configuration file for creating resources for component: Regional quality manager
# This module expects the following variables to be passed in pipeline:
#    regn_qm_state_resourcegroup_key      Key for the resource group name and state file name
#    regn_qm_state_resourcegroup_expire   Expiry date for the resource group
# This component is dependent on the following components:
#    CloudInfrastructure
#    RegionalCloudInfrastructure
#    RegionalMessageReception
#    RegionalMasterData

terraform {
  ##Backend variables are initialized by Azure DevOps
  backend "azurerm" {
    resource_group_name  = "terraform"
    storage_account_name = "#{backend_storage_account}#"
    container_name       = "#{backend_container_name}#"
    key                  = "#{regn_qm_state_resourcegroup_key}#.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=#{azurerm_version}#"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = false #SEC rem
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  resource_group_name = "#{regn_qm_state_resourcegroup_key}#"
  required_tags = {
    Application          = "IoT"
    ApplicationManager   = "sarfraz.khan@radiometer.dk"
    Build                = "#{build_number}#"
    Component            = "Regional Quality Manager"
    CostCenter           = "RMED 436"
    Criticality          = "Business Critical"
    CreatedBy            = "#{requested_for}#"
    DataSensitivityLevel = "Confidential"
    Environment          = "#{environment}#"
    Expires              = "#{regn_qm_state_resourcegroup_expire}#"
    System               = "LiveConnect Data Platform"
    SystemOwner          = "morten.hastrup@radiometer.dk"
  }
  common_tags = merge(
    local.required_tags,
    var.common_tags != null ? var.common_tags : {}
  )
}

# Resource group for the component
module "resource_group" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-resource-group?ref=v0.0.3"

  resource_group_name = local.resource_group_name
  region              = var.region
  resource_group_tags = merge(
    local.common_tags,
    var.resource_group_tags != null ? var.resource_group_tags : {}
  )
}

#---------------------------------------
# Look up the log analytics workspace from CloudInfrastructure
#---------------------------------------
data "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = var.regn_cloud_infra_log_analytics_workspace_name
  resource_group_name = var.regn_cloud_infra_resource_group_name
}

# VNet for the app service and the SQL VM
module "vnet_db" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/virtual_network?ref=v0.0.4"

  vnet_resource_group_name = local.resource_group_name
  region                   = var.region
  vnet_name                = var.vnet_name_db
  vnet_tags = merge(
    local.common_tags,
    var.vnet_tags_db != null ? var.vnet_tags_db : {}
  )
  vnet_address_space           = var.vnet_address_space_db
  vnet_bgp_community           = var.vnet_bgp_community_db
  vnet_dns_servers             = var.vnet_dns_servers_db
  vnet_edge_zone               = var.vnet_edge_zone_db
  vnet_flow_timeout_in_minutes = var.vnet_flow_timeout_in_minutes_db
  vnet_ddos_protection_plans   = var.vnet_ddos_protection_plans_db
  vnet_encryptions             = var.vnet_encryptions_db
  vnet_subnets                 = var.vnet_subnets_db
}

# subnet for the app service, and enable outbound traffic to, for instance, db access, and inbound traffic like MSDTC
module "subnet_app" {
  depends_on = [module.vnet_db]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/subnet?ref=v0.0.4"

  subnet_resource_group_name                           = local.resource_group_name
  subnet_name                                          = var.subnet_name_app
  subnet_address_prefixes                              = var.subnet_address_prefixes_app
  subnet_vnet_name                                     = var.vnet_name_db
  subnet_private_endpoint_network_policies_enabled     = var.subnet_private_endpoint_network_policies_enabled_app
  subnet_private_link_service_network_policies_enabled = var.subnet_private_link_service_network_policies_enabled_app
  subnet_service_endpoint_policy_ids                   = var.subnet_service_endpoint_policy_ids_app
  subnet_service_endpoints                             = var.subnet_service_endpoints_app
  subnet_delegations                                   = var.subnet_delegations_app
}

# subnet for the SQL VM, the database
module "subnet_db" {
  depends_on = [module.vnet_db]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/subnet?ref=v0.0.4"

  subnet_resource_group_name                           = local.resource_group_name
  subnet_name                                          = var.subnet_name_db
  subnet_address_prefixes                              = var.subnet_address_prefixes_db
  subnet_vnet_name                                     = var.vnet_name_db
  subnet_private_endpoint_network_policies_enabled     = var.subnet_private_endpoint_network_policies_enabled_db
  subnet_private_link_service_network_policies_enabled = var.subnet_private_link_service_network_policies_enabled_db
  subnet_service_endpoint_policy_ids                   = var.subnet_service_endpoint_policy_ids_db
  subnet_service_endpoints                             = var.subnet_service_endpoints_db
  subnet_delegations                                   = var.subnet_delegations_db
}

# subnet for the Data Integration Function App
module "subnet_di" {
  depends_on = [module.vnet_db]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/subnet?ref=v0.0.4"

  subnet_resource_group_name                           = local.resource_group_name
  subnet_name                                          = var.subnet_name_di
  subnet_address_prefixes                              = var.subnet_address_prefixes_di
  subnet_vnet_name                                     = var.vnet_name_db
  subnet_private_endpoint_network_policies_enabled     = var.subnet_private_endpoint_network_policies_enabled_di
  subnet_private_link_service_network_policies_enabled = var.subnet_private_link_service_network_policies_enabled_di
  subnet_service_endpoint_policy_ids                   = var.subnet_service_endpoint_policy_ids_di
  subnet_service_endpoints                             = var.subnet_service_endpoints_di
  subnet_delegations                                   = var.subnet_delegations_di
}

# TODO Integration Mdm with private end point for security and performance
# subnet for the Master data api service private endpoint
# module "subnet_pep_md_api" {
#   depends_on = [module.vnet_db]
#   source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/subnet?ref=v0.0.4"

#   subnet_resource_group_name                           = local.resource_group_name
#   subnet_name                                          = var.subnet_name_pep_md_api
#   subnet_address_prefixes                              = var.subnet_address_prefixes_pep_md_api
#   subnet_vnet_name                                     = var.vnet_name_db
#   subnet_private_endpoint_network_policies_enabled     = var.subnet_private_endpoint_network_policies_enabled_pep_md_api
#   subnet_private_link_service_network_policies_enabled = var.subnet_private_link_service_network_policies_enabled_pep_md_api
#   subnet_service_endpoint_policy_ids                   = var.subnet_service_endpoint_policy_ids_pep_md_api
#   subnet_service_endpoints                             = var.subnet_service_endpoints_pep_md_api
#   subnet_delegations                                   = var.subnet_delegations_pep_md_api
# }

# VNet for the app service pep and application gateway
module "vnet_app_agw" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/virtual_network?ref=v0.0.4"

  vnet_resource_group_name = local.resource_group_name
  region                   = var.region
  vnet_name                = var.vnet_name_app_agw
  vnet_tags = merge(
    local.common_tags,
    var.vnet_tags_app_agw != null ? var.vnet_tags_app_agw : {}
  )
  vnet_address_space           = var.vnet_address_space_app_agw
  vnet_bgp_community           = var.vnet_bgp_community_app_agw
  vnet_dns_servers             = var.vnet_dns_servers_app_agw
  vnet_edge_zone               = var.vnet_edge_zone_app_agw
  vnet_flow_timeout_in_minutes = var.vnet_flow_timeout_in_minutes_app_agw
  vnet_ddos_protection_plans   = var.vnet_ddos_protection_plans_app_agw
  vnet_encryptions             = var.vnet_encryptions_app_agw
  vnet_subnets                 = var.vnet_subnets_app_agw
}

# subnet for the app service private endpoint in application gateway VNet, for inbound traffic to appservice like api driver
module "subnet_app_pep" {
  depends_on = [module.vnet_app_agw]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/subnet?ref=v0.0.4"

  subnet_resource_group_name                           = local.resource_group_name
  subnet_name                                          = var.subnet_name_app_pep
  subnet_address_prefixes                              = var.subnet_address_prefixes_app_pep
  subnet_vnet_name                                     = var.vnet_name_app_agw
  subnet_private_endpoint_network_policies_enabled     = var.subnet_private_endpoint_network_policies_enabled_app_pep
  subnet_private_link_service_network_policies_enabled = var.subnet_private_link_service_network_policies_enabled_app_pep
  subnet_service_endpoint_policy_ids                   = var.subnet_service_endpoint_policy_ids_app_pep
  subnet_service_endpoints                             = var.subnet_service_endpoints_app_pep
  subnet_delegations                                   = var.subnet_delegations_app_pep
}

# subnet for the application gateway in application gateway VNet
module "subnet_agw" {
  depends_on = [module.vnet_app_agw]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/subnet?ref=v0.0.4"

  subnet_resource_group_name                           = local.resource_group_name
  subnet_name                                          = var.subnet_name_agw
  subnet_address_prefixes                              = var.subnet_address_prefixes_agw
  subnet_vnet_name                                     = var.vnet_name_app_agw
  subnet_private_endpoint_network_policies_enabled     = var.subnet_private_endpoint_network_policies_enabled_agw
  subnet_private_link_service_network_policies_enabled = var.subnet_private_link_service_network_policies_enabled_agw
  subnet_service_endpoint_policy_ids                   = var.subnet_service_endpoint_policy_ids_agw
  subnet_service_endpoints                             = var.subnet_service_endpoints_agw
  subnet_delegations                                   = var.subnet_delegations_agw
}

# DNS Zone for quality manager / TODO request for IT module and replace this when it is done
resource "azurerm_private_dns_zone" "qm" {
  depends_on = [module.resource_group]

  name                = "privatelink.azurewebsites.net"
  resource_group_name = local.resource_group_name
}

# Link the private DNS zone to the vnet app agw
module "private_dns_vnet_link_app_agw" {
  depends_on = [azurerm_private_dns_zone.qm]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/private_dns_vnet_link?ref=v0.0.4"

  vnet_pvtdns_link_dns_resource_group_name = local.resource_group_name

  vnet_pvtdns_link_virtual_network_name  = "vnet-app-agw"
  vnet_pvtdns_link_private_dns_zone_name = "privatelink.azurewebsites.net"
  vnet_pvtdns_link_virtual_network_id    = module.vnet_app_agw.vnet_id
  vnet_pvtdns_link_tags                  = var.common_tags
  vnet_pvtdns_link_registration_enabled  = true
}

# Link the private DNS zone to the vnet db (vnet db uses private link to access services hosted in app services)
module "private_dns_vnet_link_db" {
  depends_on = [azurerm_private_dns_zone.qm]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/private_dns_vnet_link?ref=v0.0.4"

  vnet_pvtdns_link_dns_resource_group_name = local.resource_group_name

  vnet_pvtdns_link_virtual_network_name  = "vnet-db"
  vnet_pvtdns_link_private_dns_zone_name = "privatelink.azurewebsites.net"
  vnet_pvtdns_link_virtual_network_id    = module.vnet_db.vnet_id
  vnet_pvtdns_link_tags                  = var.common_tags
  vnet_pvtdns_link_registration_enabled  = true
}

# Public IP for the SQL VM
module "public_ip_db_vm" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-public-ip?ref=v0.0.1"

  azure_public_ip_resource_group_name = local.resource_group_name
  region                              = var.region
  azure_public_ip_tags = merge(
    local.common_tags,
    var.public_ip_tags_db_vm != null ? var.public_ip_tags_db_vm : {}
  )

  azure_public_ip_name                    = var.public_ip_name_db_vm
  azure_public_ip_allocation_method       = var.public_ip_allocation_method_db_vm
  azure_public_ip_zones                   = var.public_ip_zones_db_vm
  azure_public_ip_ddos_protection_plan_id = var.public_ip_ddos_protection_plan_id_db_vm
  azure_public_ip_domain_name_label       = var.public_ip_domain_name_label_db_vm
  azure_public_ip_edge_zone               = var.public_ip_edge_zone_db_vm
  azure_public_ip_idle_timeout_in_minutes = var.public_ip_idle_timeout_in_minutes_db_vm
  azure_public_ip_ip_tags                 = var.public_ip_ip_tags_db_vm
  azure_public_ip_ip_version              = var.public_ip_ip_version_db_vm
  azure_public_ip_public_ip_prefix_id     = var.public_ip_public_ip_prefix_id_db_vm
  azure_public_ip_reverse_fqdn            = var.public_ip_reverse_fqdn_db_vm
  azure_public_ip_sku                     = var.public_ip_sku_db_vm
  azure_public_ip_sku_tier                = var.public_ip_sku_tier_db_vm
}

# Storage account for the Quality manager component, used by SQL VM and and app service
module "storage_account" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-storage//modules/storage_account?ref=v0.0.7"

  storage_account_resource_group_name             = local.resource_group_name
  region                                          = var.region
  storage_account_name                            = var.storage_account_name
  storage_account_kind                            = var.storage_account_kind
  storage_account_replication_type                = var.storage_account_replication_type
  storage_account_allow_nested_items_to_be_public = var.storage_account_allow_nested_items_to_be_public
  storage_account_enable_https_traffic_only       = var.storage_account_enable_https_traffic_only
  storage_account_is_hns_enabled                  = var.storage_account_is_hns_enabled
  storage_account_large_file_share_enabled        = var.storage_account_large_file_share_enabled
  storage_account_shared_access_key_enabled       = var.storage_account_shared_access_key_enabled
  storage_account_min_tls_version                 = var.storage_account_min_tls_version
  storage_account_tags = merge(
    local.common_tags,
    var.storage_account_tags != null ? var.storage_account_tags : {}
  )
  storage_account_public_network_access_enabled     = var.storage_account_public_network_access_enabled
  storage_account_cross_tenant_replication_enabled  = var.storage_account_cross_tenant_replication_enabled
  storage_account_infrastructure_encryption_enabled = var.storage_account_infrastructure_encryption_enabled
  storage_account_sas_policy_enabled                = var.storage_account_sas_policy_enabled
  storage_account_sas_policy_expiration_period      = var.storage_account_sas_policy_expiration_period
  storage_account_sas_policy_expiration_action      = var.storage_account_sas_policy_expiration_action
  storage_account_identity_type                     = var.storage_account_identity_type
  storage_account_identity_ids                      = var.storage_account_identity_ids
  storage_account_network_rules = [
    {
      bypass                     = ["AzureServices"]
      default_action             = "Deny"
      ip_rules                   = var.storage_account_network_ip_rules
      virtual_network_subnet_ids = [module.subnet_db.subnet_id, module.subnet_app.subnet_id, module.subnet_di.subnet_id]
    }
  ]

  storage_account_blob_properties = var.storage_account_blob_properties
  storage_account_tier            = var.storage_account_tier
  storage_account_access_tier     = var.storage_account_access_tier
}

# Storage container to upload scripts for the SQL VM
module "storage_container_db_vm" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-storage//modules/container?ref=v0.0.7"

  storage_account_name                  = module.storage_account.storage_account_name
  storage_account_container_name        = var.storage_account_container_name_regn_qm
  storage_account_container_access_type = var.storage_account_container_access_type_regn_qm
  storage_account_container_metadata    = var.storage_account_container_metadata_regn_qm
}

// TODO request for IT module and replace this when it is done
# Upload db scripts to the storage container as blobs
resource "azurerm_storage_blob" "scripts_regn_qm_db" {
  depends_on = [module.storage_container_db_vm]
  for_each   = fileset("${path.module}/scripts", "db_*.*")

  name                   = each.value
  storage_account_name   = var.storage_account_name
  storage_container_name = var.storage_account_container_name_regn_qm
  type                   = "Block"
  source                 = "${path.module}/scripts/${each.value}"
  content_md5            = filemd5("${path.module}/scripts/${each.value}")
}

resource "azurerm_storage_blob" "falcon_sensor_regn_qm_db" {
  depends_on = [module.storage_container_db_vm]

  name                   = var.falcon_sensor_installer_name
  storage_account_name   = var.storage_account_name
  storage_container_name = var.storage_account_container_name_regn_qm
  type                   = "Block"
  content_md5            = filemd5(var.falcon_sensor_installer_path)
  source                 = var.falcon_sensor_installer_path
}

# Storage file share for the app service, as the entry point for custom scripts or other files
module "storage_account_fileshare_qm_app" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-storage//modules/file_share?ref=v0.0.7"

  storage_fileshare_name                 = var.storage_fileshare_name_qm_app
  storage_fileshare_storage_account_name = module.storage_account.storage_account_name
  storage_fileshare_quota                = var.storage_fileshare_quota_qm_app
  storage_fileshare_access_tier          = var.storage_fileshare_access_tier_qm_app
  storage_fileshare_enabled_protocol     = var.storage_fileshare_enabled_protocol_qm_app
  storage_fileshare_metadata             = var.storage_fileshare_metadata_qm_app
  storage_fileshare_acls                 = var.storage_fileshare_acls_qm_app
}

# Storage file share for the app service msmq
module "storage_account_fileshare_qm_app_msmq" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-storage//modules/file_share?ref=v0.0.7"

  storage_fileshare_name                 = var.storage_fileshare_name_qm_app_msmq
  storage_fileshare_storage_account_name = module.storage_account.storage_account_name
  storage_fileshare_quota                = var.storage_fileshare_quota_qm_app_msmq
  storage_fileshare_access_tier          = var.storage_fileshare_access_tier_qm_app_msmq
  storage_fileshare_enabled_protocol     = var.storage_fileshare_enabled_protocol_qm_app_msmq
  storage_fileshare_metadata             = var.storage_fileshare_metadata_qm_app_msmq
  storage_fileshare_acls                 = var.storage_fileshare_acls_qm_app_msmq
}

# Upload app scripts to the storage file share as share file
resource "azurerm_storage_share_file" "scripts_regn_qm_app" {
  depends_on = [module.storage_account_fileshare_qm_app]
  for_each   = fileset("${path.module}/scripts", "app_*.ps1")

  name             = each.value
  storage_share_id = module.storage_account_fileshare_qm_app.storage_share_id
  source           = "${path.module}/scripts/${each.value}"
  content_md5      = filemd5("${path.module}/scripts/${each.value}")
}

# Upload app tools to the storage file share as share file
resource "azurerm_storage_share_directory" "tools_regn_qm_app" {
  name             = "tools"
  storage_share_id = module.storage_account_fileshare_qm_app.storage_share_id
}

resource "azurerm_storage_share_file" "tools_regn_qm_app" {
  depends_on = [module.storage_account_fileshare_qm_app, azurerm_storage_share_directory.tools_regn_qm_app]
  for_each   = fileset("${path.module}/tools/app_vm", "*.ps1")

  name             = each.value
  path             = "tools"
  storage_share_id = module.storage_account_fileshare_qm_app.storage_share_id
  source           = "${path.module}/tools/app_vm/${each.value}"
  content_md5      = filemd5("${path.module}/tools/app_vm/${each.value}")
}

# Network security group for the SQL VM
module "network_security_group_db_vm" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/network_security_group?ref=v0.0.4"

  nsg_resource_group_name = local.resource_group_name
  region                  = var.region
  nsg_name                = var.nsg_name_db_vm
  nsg_tags = merge(
    local.common_tags,
    var.nsg_tags_db_vm != null ? var.nsg_tags_db_vm : {}
  )
  nsg_security_rules = var.nsg_security_rules_db_vm
}

# Associate the subnet with the NSG
module "subnet_nsg_association_db_vm" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-network//modules/subnet_nsg_association?ref=v0.0.4"

  nsgsnet_asso_subnet_id                 = module.subnet_db.subnet_id
  nsgsnet_asso_network_security_group_id = module.network_security_group_db_vm.nsg_id
}

# Windows VM for the SQL Server
module "db_vm" {
  depends_on = [module.storage_container_db_vm]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-windows-vm?ref=v0.0.6"

  windows_vm_resource_group_name = local.resource_group_name
  region                         = var.region
  catalog                        = null # not used, but required by the module (get new dynamic rg Name)
  DeployVMResourceGroup          = false
  AzUsername                     = null # not used, but required by the module (get new dynamic VM Name)
  AzPassword                     = null # not used, but required by the module (get new dynamic VM Name)
  AzTenantId                     = null # not used, but required by the module (get new dynamic VM Name)
  GetDynamicVMName               = false

  windows_vm_tags = merge(
    local.common_tags,
    var.db_vm_tags != null ? var.db_vm_tags : {}
  )
  windows_vm_compute_subnet_id                                      = module.subnet_db.subnet_id
  windows_vm_admin                                                  = var.db_vm_admin
  windows_vm_admin_password                                         = var.db_vm_admin_password
  windows_vm_license_type                                           = var.db_vm_license_type
  windows_vm_identity_type                                          = var.db_vm_identity_type
  windows_virtual_machine_name                                      = var.db_vm_name
  windows_vm_private_ip_address_allocation                          = var.db_vm_private_ip_address_allocation
  windows_vm_size                                                   = var.db_vm_size
  windows_vm_os_disk_caching                                        = var.db_vm_os_disk_caching
  windows_vm_os_disk_type                                           = var.db_vm_os_disk_type
  windows_vm_os_disk_size_gb                                        = var.db_vm_os_disk_size_gb
  UseCustomImage                                                    = var.db_vm_use_custom_image
  windows_vm_source_image_id                                        = var.db_vm_source_image_id
  windows_vm_source_image_publisher                                 = var.db_vm_source_image_publisher
  windows_vm_source_image_offer                                     = var.db_vm_source_image_offer
  windows_vm_source_image_sku                                       = var.db_vm_source_image_sku
  windows_vm_source_image_version                                   = var.db_vm_source_image_version
  windows_vm_identity_ids                                           = var.db_vm_identity_ids
  windows_vm_public_ip_address_id                                   = module.public_ip_db_vm.public_ip_id
  windows_vm_boot_diag_storage_account_uri                          = var.db_vm_boot_diag_storage_account_uri
  windows_vm_enable_boot_diagnostics                                = var.db_vm_enable_boot_diagnostics
  windows_vm_disk_encryption_set_id                                 = var.db_vm_disk_encryption_set_id
  windows_vm_zone                                                   = var.db_vm_zone
  windows_vm_patch_mode                                             = var.db_vm_patch_mode
  windows_vm_bypass_platform_safety_checks_on_user_schedule_enabled = var.db_vm_bypass_platform_safety_checks_on_user_schedule_enabled
  windows_vm_encryption_at_host_enabled                             = var.db_vm_encryption_at_host_enabled
}

# Managed data disk for the SQL VM
module "db_vm_datadisk" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-disk-management//modules/managed_disk_creation?ref=v0.0.3"

  managed_disk_resource_group_name = local.resource_group_name
  region                           = var.region

  managed_disk_virtual_machine_name = module.db_vm.windows_virtual_machine_name
  managed_disk_revision             = var.db_data_managed_disk_revision
  managed_disk_type                 = var.db_data_managed_disk_type
  managed_disk_create_option        = var.db_data_managed_disk_create_option
  managed_disk_size_gb              = var.db_data_managed_disk_size_gb
  managed_disk_zone                 = var.db_data_managed_disk_zone
  managed_disk_tags = merge(
    local.common_tags,
    var.db_data_managed_disk_tags != null ? var.db_data_managed_disk_tags : {}
  )
  managed_disk_disk_access_id             = var.db_data_managed_disk_disk_access_id
  managed_disk_disk_encryption_set_id     = var.db_data_managed_disk_disk_encryption_set_id
  managed_disk_disk_iops_read_only        = var.db_data_managed_disk_disk_iops_read_only
  managed_disk_disk_iops_read_write       = var.db_data_managed_disk_disk_iops_read_write
  managed_disk_disk_mbps_read_only        = var.db_data_managed_disk_disk_mbps_read_only
  managed_disk_disk_mbps_read_write       = var.db_data_managed_disk_disk_mbps_read_write
  managed_disk_edge_zone                  = var.db_data_managed_disk_edge_zone
  managed_disk_gallery_image_reference_id = var.db_data_managed_disk_gallery_image_reference_id
  managed_disk_hyper_v_generation         = var.db_data_managed_disk_hyper_v_generation
  managed_disk_image_reference_id         = var.db_data_managed_disk_image_reference_id
  managed_disk_logical_sector_size        = var.db_data_managed_disk_logical_sector_size
}

# Attach the managed data disk to the SQL VM
module "db_vm_datadisk_attachment" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-disk-management//modules/managed_disk_attachment?ref=v0.0.3"

  managed_data_disk_id      = module.db_vm_datadisk.managed_disk_id
  managed_data_disk_vm_id   = module.db_vm.virtual_machine_id
  managed_data_disk_lun     = var.db_data_managed_disk_lun
  managed_data_disk_caching = var.db_data_managed_disk_caching
}

# Managed log disk for the SQL VM
module "db_vm_logdisk" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-disk-management//modules/managed_disk_creation?ref=v0.0.3"

  managed_disk_resource_group_name = local.resource_group_name
  region                           = var.region

  managed_disk_virtual_machine_name = module.db_vm.windows_virtual_machine_name
  managed_disk_revision             = var.db_log_managed_disk_revision
  managed_disk_type                 = var.db_log_managed_disk_type
  managed_disk_create_option        = var.db_log_managed_disk_create_option
  managed_disk_size_gb              = var.db_log_managed_disk_size_gb
  managed_disk_zone                 = var.db_log_managed_disk_zone
  managed_disk_tags = (
    var.db_log_managed_disk_tags == null
    ? var.common_tags
    : var.db_log_managed_disk_tags
  )
  managed_disk_disk_access_id             = var.db_log_managed_disk_disk_access_id
  managed_disk_disk_encryption_set_id     = var.db_log_managed_disk_disk_encryption_set_id
  managed_disk_disk_iops_read_only        = var.db_log_managed_disk_disk_iops_read_only
  managed_disk_disk_iops_read_write       = var.db_log_managed_disk_disk_iops_read_write
  managed_disk_disk_mbps_read_only        = var.db_log_managed_disk_disk_mbps_read_only
  managed_disk_disk_mbps_read_write       = var.db_log_managed_disk_disk_mbps_read_write
  managed_disk_edge_zone                  = var.db_log_managed_disk_edge_zone
  managed_disk_gallery_image_reference_id = var.db_log_managed_disk_gallery_image_reference_id
  managed_disk_hyper_v_generation         = var.db_log_managed_disk_hyper_v_generation
  managed_disk_image_reference_id         = var.db_log_managed_disk_image_reference_id
  managed_disk_logical_sector_size        = var.db_log_managed_disk_logical_sector_size
}

# Attach the managed log disk to the SQL VM
module "db_vm_logdisk_attachment" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-disk-management//modules/managed_disk_attachment?ref=v0.0.3"

  managed_data_disk_id      = module.db_vm_logdisk.managed_disk_id
  managed_data_disk_vm_id   = module.db_vm.virtual_machine_id
  managed_data_disk_lun     = var.db_log_managed_disk_lun
  managed_data_disk_caching = var.db_log_managed_disk_caching
}

# Role assignment for the SQL VM managed identity to access the storage account
module "role_assignment_db_vm_to_storage" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-role-management//modules/role_assignment?ref=v0.0.2"

  role_assignment_scope                = module.storage_account.storage_account_id
  role_assignment_role_definition_name = "Storage Blob Data Reader"
  role_assignment_principal_id         = module.db_vm.virtual_machine_principal_id
  role_assignment_description          = "Read access to storage account for VM"
}

# SQL VM, Azure SQL VM deployment requres a Windows_VM block and a SQL_Machine block
module "db_sql_vm" {
  depends_on = [module.db_vm_datadisk_attachment, module.db_vm_logdisk_attachment]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-sql-machine?ref=v0.0.2"

  mssql_vm_virtual_machine_id               = module.db_vm.virtual_machine_id
  mssql_vm_sql_license_type                 = var.db_mssql_vm_sql_license_type
  mssql_vm_r_services_enabled               = var.db_mssql_vm_r_services_enabled
  mssql_vm_sql_connectivity_port            = var.db_mssql_vm_sql_connectivity_port
  mssql_vm_sql_connectivity_type            = var.db_mssql_vm_sql_connectivity_type
  mssql_vm_sql_connectivity_update_password = var.db_mssql_vm_sql_connectivity_update_password
  mssql_vm_sql_connectivity_update_username = var.db_mssql_vm_sql_connectivity_update_username
  mssql_vm_tags = merge(
    local.common_tags,
    var.db_mssql_vm_tags != null ? var.db_mssql_vm_tags : {}
  )
  mssql_assessments = var.db_mssql_vm_assessments

  mssql_auto_backups = [
    {
      retention_period_in_days        = var.db_mssql_vm_backup_retention_period_in_days
      storage_blob_endpoint           = data.azurerm_storage_account.qm.primary_blob_endpoint
      storage_account_access_key      = data.azurerm_storage_account.qm.primary_access_key
      system_databases_backup_enabled = var.db_mssql_vm_backup_system_databases_enabled
      backup_schedule_type            = var.db_mssql_vm_backup_schedule_type
      backup_encryption_enabled       = var.db_mssql_vm_backup_encryption_enabled
      encryption_enabled              = var.db_mssql_vm_backup_encryption_enabled
      encryption_password             = var.db_mssql_vm_backup_encryption_password
      manual_schedules = [
        {
          days_of_week                    = var.db_mssql_vm_backup_days_of_week
          full_backup_frequency           = var.db_mssql_vm_backup_full_frequency
          full_backup_start_hour          = var.db_mssql_vm_backup_full_start_hour
          full_backup_window_in_hours     = var.db_mssql_vm_backup_full_window_hours
          log_backup_frequency_in_minutes = var.db_mssql_vm_backup_log_frequency_minutes
        }
      ]
    }
  ]

  mssql_auto_patchings          = var.db_mssql_vm_auto_patchings
  mssql_key_vault_credentials   = var.db_mssql_vm_key_vault_credentials
  mssql_sql_instances           = var.db_mssql_vm_sql_instances
  mssql_storage_configurations  = var.db_mssql_vm_storage_configurations
  mssql_wsfc_domain_credentials = var.db_mssql_vm_wsfc_domain_credentials
}

module "db_vm_extension_custom_script" {
  depends_on = [module.role_assignment_db_vm_to_storage, module.db_sql_vm]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-vm-extension?ref=v0.0.2"

  vm_extension_name                      = "CustomScriptExtension.VM.Initialization"
  vm_extension_virtual_machine_id        = module.db_vm.virtual_machine_id
  vm_extension_publisher                 = "Microsoft.Compute"
  vm_extension_type                      = "CustomScriptExtension"
  vm_extension_type_handler_version      = var.db_vm_extension_custom_script_version
  vm_extension_tags                      = local.common_tags
  vm_extension_automatic_upgrade_enabled = false
  vm_extension_protected_settings        = <<SETTINGS
  {
    "fileUris" : ["${azurerm_storage_blob.scripts_regn_qm_db["db_vm_initialization.ps1"].url}", "${azurerm_storage_blob.scripts_regn_qm_db["db_MaintenanceSolution.sql"].url}", "${azurerm_storage_blob.falcon_sensor_regn_qm_db.url}"],
    "commandToExecute" : "powershell -ExecutionPolicy Unrestricted -File db_vm_initialization.ps1 -DnsSuffix privatelink.azurewebsites.net -SQLAdminUserName ${var.db_mssql_vm_sql_connectivity_update_username} -SQLAdminPassword ${var.db_mssql_vm_sql_connectivity_update_password} -FalconSensorExeName ${var.falcon_sensor_installer_name} -FalconSensorCid ${var.falcon_sensor_customer_id}",
    "managedIdentity" : {}
  }
  SETTINGS
}

# Application insight for the QualityManager app
module "app_insight_qm_app" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-applicationinsight?ref=v0.0.1"

  application_insight_resource_group_name = local.resource_group_name
  region                                  = var.region
  application_insight_tags = merge(
    local.common_tags,
    var.qm_app_application_insight_tags != null ? var.qm_app_application_insight_tags : {}
  )

  application_insight_name                                  = var.qm_app_application_insight_name
  application_insight_workspace_id                          = data.azurerm_log_analytics_workspace.log_analytics_workspace.id
  application_insight_application_type                      = "other"
  application_insight_daily_data_cap_in_gb                  = var.qm_app_application_insight_daily_data_cap_in_gb
  application_insight_daily_data_cap_notifications_disabled = var.qm_app_application_insight_daily_data_cap_notifications_disabled
  application_insight_retention_in_days                     = var.qm_app_application_insight_retention_in_days
  application_insight_sampling_percentage                   = var.qm_app_application_insight_sampling_percentage
  application_insight_disable_ip_masking                    = var.qm_app_application_insight_disable_ip_masking
  application_insight_local_authentication_disabled         = var.qm_app_application_insight_local_authentication_disabled
  application_insight_internet_ingestion_enabled            = var.qm_app_application_insight_internet_ingestion_enabled
  application_insight_internet_query_enabled                = var.qm_app_application_insight_internet_query_enabled
  application_insight_force_customer_storage_for_profiler   = var.qm_app_application_insight_force_customer_storage_for_profiler
}

# App service plan for the Quality Manager app service
module "app_service_plan_qm" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-app-service-plan?ref=v0.0.2"

  app_service_plan_resource_group_name = local.resource_group_name
  region                               = var.region
  app_service_plan_tags = merge(
    local.common_tags,
    var.app_service_plan_tags != null ? var.app_service_plan_tags : {}
  )

  app_service_plan_name                         = var.app_service_plan_name
  app_service_plan_os_type                      = "WindowsContainer"
  app_service_plan_sku_name                     = var.app_service_plan_sku_name
  app_service_plan_app_service_environment_id   = var.app_service_plan_app_service_environment_id
  app_service_plan_maximum_elastic_worker_count = var.app_service_plan_maximum_elastic_worker_count
  app_service_plan_per_site_scaling_enabled     = var.app_service_plan_per_site_scaling_enabled
  app_service_plan_worker_count                 = var.app_service_plan_worker_count
  app_service_plan_zone_balancing_enabled       = var.app_service_plan_zone_balancing_enabled
}

data "azurerm_storage_account" "qm" {
  depends_on = [module.storage_account]

  name                = module.storage_account.storage_account_name
  resource_group_name = local.resource_group_name
}

data "azurerm_container_registry" "registry" {
  name                = var.windows_appservice_container_registry_name
  resource_group_name = var.windows_appservice_container_registry_resource_group
}

# App service for the Quality manager
module "app_service_qm" {
  depends_on = [module.app_service_plan_qm, module.storage_account_fileshare_qm_app, module.db_sql_vm]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-windows-appservice?ref=v0.0.6"

  windows_appservice_resource_group_name = local.resource_group_name
  region                                 = var.region
  windows_appservice_tags = merge(
    local.common_tags,
    var.windows_appservice_tags != null ? var.windows_appservice_tags : {}
  )

  windows_appservice_name                               = var.windows_appservice_name
  windows_appservice_service_plan_id                    = module.app_service_plan_qm.app_service_plan_id
  windows_appservice_client_affinity_enabled            = var.windows_appservice_client_affinity_enabled
  windows_appservice_client_certificate_enabled         = var.windows_appservice_client_certificate_enabled
  windows_appservice_client_certificate_mode            = var.windows_appservice_client_certificate_mode
  windows_appservice_client_certificate_exclusion_paths = var.windows_appservice_client_certificate_exclusion_paths
  windows_appservice_enabled                            = var.windows_appservice_enabled
  windows_appservice_https_only                         = var.windows_appservice_https_only
  windows_appservice_key_vault_reference_identity_id    = var.windows_appservice_key_vault_reference_identity_id
  windows_appservice_virtual_network_subnet_id          = module.subnet_app.subnet_id
  windows_appservice_zip_deploy_file                    = var.windows_appservice_zip_deploy_file
  windows_appservice_public_network_access_enabled      = var.windows_appservice_public_network_access_enabled
  windows_appservice_app_settings = merge(
    var.windows_appservice_app_settings,
    {
      WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
      WEBSITES_PORT                       = "80"
      DNSSUFFIX                           = "privatelink.azurewebsites.net"
      CUSTOMCONFIGFOLDER                  = "C:\\AppData"
      PRV_DNSZONE_NAME                    = "privatelink.azurewebsites.net"
      PRV_DNSZONE_RG                      = "#{regn_qm_state_resourcegroup_key}#"
      APPINSIGHTCONNECTIONSTRING          = module.app_insight_qm_app.application_insight_cnnection_string
      MASTERDATAAPICLIENTID               = var.mdm_app_client_id
      MASTERDATAAPITENANTID               = var.mdm_app_tenant_id
      MASTERDATAAPICLIENTSECRET           = var.mdm_app_client_secret
      MASTERDATAAPISERVICEROOT            = var.mdm_api_base_url
      MASTERDATAAPIHOSPITALFILTER         = "Region/Code eq '${var.mdm_region_code}'"
    }
  )
  windows_appservice_application_stack = [{
    current_stack                = null
    docker_image_name            = var.windows_appservice_container_image_qm_name
    docker_registry_url          = "https://${data.azurerm_container_registry.registry.login_server}"
    docker_container_name        = "${data.azurerm_container_registry.registry.login_server}/${var.windows_appservice_container_image_qm_name}"
    docker_container_tag         = var.windows_appservice_container_image_qm_tag
    docker_registry_username     = null #managed identity
    docker_registry_password     = null #managed identity
    dotnet_version               = null
    dotnet_core_version          = null
    tomcat_version               = null
    java_embedded_server_enabled = null
    java_version                 = null
    node_version                 = null
    python                       = null
  }]

  windows_appservice_vnet_route_all_enabled                   = var.windows_appservice_vnet_route_all_enabled
  windows_appservice_ftp_publish_basic_authentication_enabled = var.windows_appservice_ftp_publish_basic_authentication_enabled
  windows_appservice_app_command_line                         = var.windows_appservice_app_command_line
  windows_appservice_http2_enabled                            = var.windows_appservice_http2_enabled
  windows_appservice_ip_restrictions                          = var.windows_appservice_ip_restrictions
  windows_appservice_scm_ip_restrictions                      = var.windows_appservice_scm_ip_restrictions
  windows_appservice_identity                                 = var.windows_appservice_identity
  windows_appservice_backup                                   = var.windows_appservice_backup
  windows_appservice_connection_string                        = var.windows_appservice_connection_string
  windows_appservice_logs                                     = var.windows_appservice_logs
  windows_appservice_storage_accounts = [{
    name         = "qm-app-data"
    account_name = module.storage_account.storage_account_name
    share_name   = var.storage_fileshare_name_qm_app
    access_key   = data.azurerm_storage_account.qm.primary_access_key //TODO when AzureRm support managed identity without access_key, replace this
    type         = "AzureFiles"
    mount_path   = "/AppData"
    },
    {
      name         = "qm-app-msmq"
      account_name = module.storage_account.storage_account_name
      share_name   = var.storage_fileshare_name_qm_app_msmq
      access_key   = data.azurerm_storage_account.qm.primary_access_key //TODO when AzureRm support managed identity without access_key, replace this
      type         = "AzureFiles"
      mount_path   = "/MsmqData"
    }
  ]
  windows_appservice_sticky_settings                               = var.windows_appservice_sticky_settings
  windows_appservice_auth_settings                                 = var.windows_appservice_auth_settings
  windows_appservice_health_check_path                             = var.windows_appservice_health_check_path
  windows_appservice_health_check_eviction_time_in_min             = var.windows_appservice_health_check_eviction_time_in_min
  windows_appservice_scm_use_main_ip_restriction                   = var.windows_appservice_scm_use_main_ip_restriction
  windows_appservice_auth_settings_v2                              = var.windows_appservice_auth_settings_v2
  windows_appservice_api_definition_url                            = var.windows_appservice_api_definition_url
  windows_appservice_api_management_api_id                         = var.windows_appservice_api_management_api_id
  windows_appservice_container_registry_managed_identity_client_id = var.windows_appservice_container_registry_managed_identity_client_id
  windows_appservice_container_registry_use_managed_identity       = var.windows_appservice_container_registry_use_managed_identity
  windows_appservice_ip_restriction_default_action                 = var.windows_appservice_ip_restriction_default_action
  windows_appservice_managed_pipeline_mode                         = var.windows_appservice_managed_pipeline_mode
  windows_appservice_minimum_tls_version                           = var.windows_appservice_minimum_tls_version
  windows_appservice_remote_debugging_enabled                      = var.windows_appservice_remote_debugging_enabled
  windows_appservice_remote_debugging_version                      = var.windows_appservice_remote_debugging_version
  windows_appservice_scm_ip_restriction_default_action             = var.windows_appservice_scm_ip_restriction_default_action
  windows_appservice_scm_minimum_tls_version                       = var.windows_appservice_scm_minimum_tls_version
  windows_appservice_websockets_enabled                            = var.windows_appservice_websockets_enabled
  windows_appservice_worker_count                                  = var.windows_appservice_worker_count
}

# Role assignment for the app service managed identity to access the azure container registry
module "role_assignment_app_svc_to_acr" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-role-management//modules/role_assignment?ref=v0.0.2"

  role_assignment_scope                = data.azurerm_container_registry.registry.id
  role_assignment_role_definition_name = "AcrPull"
  role_assignment_principal_id         = module.app_service_qm.windows_appservice_principal_id
  role_assignment_description          = "Pull access to container registry for app service"
}

# Role assignment for the app service managed identity to access the private DNS zone, this is required for the AppService, 
# in its initialization script, register its hostname in the private DNS zone, so DTC can resolve the hostname to the private IP from the SQL VM.
module "role_assignment_app_svc_to_prv_dns" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-role-management//modules/role_assignment?ref=v0.0.2"

  role_assignment_scope                = azurerm_private_dns_zone.qm.id
  role_assignment_role_definition_name = "Private DNS Zone Contributor"
  role_assignment_principal_id         = module.app_service_qm.windows_appservice_principal_id
  role_assignment_description          = "Contributor access to private DNS zone for app service"
}

# Private endpoint for the app service frontend in the application gateway VNet, this is entry point for ApplicationGateway to access the app service
module "private_endpoint_app" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-private-endpoint?ref=v0.0.1"

  pep_resource_group_name = local.resource_group_name
  region                  = var.region
  pep_tags = merge(
    local.common_tags,
    var.pep_tags_app != null ? var.pep_tags_app : {}
  )

  pep_name                 = var.pep_name_app
  pep_subnet_id            = module.subnet_app_pep.subnet_id
  pep_psc_name             = "agw_to_app_service_qm"
  pep_resource_id          = module.app_service_qm.windows_appservice_id
  pep_subresource_names    = "sites"
  pep_is_manual_connection = false
  pep_private_dns_zone_group = [{
    pep_private_dns_zone_group_name = "qm.privatelink.azurewebsites.net"
    pep_private_dns_zone_ids        = [azurerm_private_dns_zone.qm.id]
  }]
}

data "azurerm_windows_web_app" "qm" {
  depends_on = [module.app_service_qm]

  name                = var.windows_appservice_name
  resource_group_name = local.resource_group_name
}

resource "azurerm_dns_txt_record" "qm_asuid" {
  # Conditional deployment of dns record for the app service
  count      = var.windows_appservice_dns_zone_registration ? 1 : 0
  depends_on = [module.resource_group]

  name                = "asuid.${var.windows_appservice_custom_hostname}"
  zone_name           = var.windows_appservice_dns_zone_name
  resource_group_name = var.windows_appservice_dns_zone_resource_group
  ttl                 = 3600

  record {
    value = data.azurerm_windows_web_app.qm.custom_domain_verification_id
  }
}

#TODO request for IT module and replace this when it is done
resource "azurerm_dns_cname_record" "qm" {
  # Conditional deployment of dns record for the app service
  count      = var.windows_appservice_dns_zone_registration ? 1 : 0
  depends_on = [module.resource_group]

  name                = var.windows_appservice_custom_hostname
  zone_name           = var.windows_appservice_dns_zone_name
  resource_group_name = var.windows_appservice_dns_zone_resource_group
  ttl                 = 3600
  record              = data.azurerm_windows_web_app.qm.default_hostname
}

# Due to potential dns propagation time, using this waitting task make sure the host name binding can find the asuid record
resource "time_sleep" "wait_30_seconds_after_dns_asuid_record" {
  depends_on = [azurerm_dns_txt_record.qm_asuid]

  create_duration = "30s"
}

# TODO request for IT module and replace this when it is done
resource "azurerm_app_service_custom_hostname_binding" "qm" {
  depends_on = [module.app_service_qm, time_sleep.wait_30_seconds_after_dns_asuid_record]

  hostname            = "${var.windows_appservice_custom_hostname}.${var.windows_appservice_dns_zone_name}"
  app_service_name    = var.windows_appservice_name
  resource_group_name = local.resource_group_name
}

# TODO request for IT module and replace this when it is done
resource "azurerm_app_service_certificate" "qm" {
  # Conditional deployment of dns record for the app service
  count      = var.azure_appgateway_certificate_key_vault_secret_id != null ? 1 : 0
  depends_on = [module.resource_group]

  resource_group_name = local.resource_group_name
  location            = var.region
  name                = "appservice_ssl_certificate"
  key_vault_secret_id = var.azure_appgateway_certificate_key_vault_secret_id
  password            = var.azure_appgateway_certificate_password
}

resource "azurerm_app_service_certificate_binding" "qm" {
  # Conditional deployment of dns record for the app service
  count = var.azure_appgateway_certificate_key_vault_secret_id != null ? 1 : 0

  hostname_binding_id = azurerm_app_service_custom_hostname_binding.qm.id
  certificate_id      = azurerm_app_service_certificate.qm[0].id
  ssl_state           = "SniEnabled"
}

resource "azurerm_app_service_certificate" "qm_pfx" {
  # Conditional deployment of dns record for the app service
  count      = var.azure_appgateway_certificate_pfx != null ? 1 : 0
  depends_on = [module.resource_group]

  resource_group_name = local.resource_group_name
  location            = var.region
  name                = "appservice_ssl_certificate_pfx"
  pfx_blob            = filebase64(var.azure_appgateway_certificate_pfx)
  password            = var.azure_appgateway_certificate_password
  app_service_plan_id = module.app_service_plan_qm.app_service_plan_id
}

resource "azurerm_app_service_certificate_binding" "qm_pfx" {
  depends_on = [azurerm_app_service_certificate.qm_pfx]
  # Conditional deployment of dns record for the app service
  count = var.azure_appgateway_certificate_pfx != null ? 1 : 0

  hostname_binding_id = azurerm_app_service_custom_hostname_binding.qm.id
  certificate_id      = azurerm_app_service_certificate.qm_pfx[0].id
  ssl_state           = "SniEnabled"
}

# Public IP for the Application gateway
module "public_ip_agw" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-public-ip?ref=v0.0.1"

  azure_public_ip_resource_group_name = local.resource_group_name
  region                              = var.region
  azure_public_ip_tags = merge(
    local.common_tags,
    var.public_ip_tags_agw != null ? var.public_ip_tags_agw : {}
  )

  azure_public_ip_name                    = var.public_ip_name_agw
  azure_public_ip_allocation_method       = var.public_ip_allocation_method_agw
  azure_public_ip_zones                   = var.public_ip_zones_agw
  azure_public_ip_ddos_protection_plan_id = var.public_ip_ddos_protection_plan_id_agw
  azure_public_ip_domain_name_label       = var.public_ip_domain_name_label_agw
  azure_public_ip_edge_zone               = var.public_ip_edge_zone_agw
  azure_public_ip_idle_timeout_in_minutes = var.public_ip_idle_timeout_in_minutes_agw
  azure_public_ip_ip_tags                 = var.public_ip_ip_tags_agw
  azure_public_ip_ip_version              = var.public_ip_ip_version_agw
  azure_public_ip_public_ip_prefix_id     = var.public_ip_public_ip_prefix_id_agw
  azure_public_ip_reverse_fqdn            = var.public_ip_reverse_fqdn_agw
  azure_public_ip_sku                     = var.public_ip_sku_agw
  azure_public_ip_sku_tier                = var.public_ip_sku_tier_agw
}

#TODO request for IT module and replace this when it is done
resource "azurerm_web_application_firewall_policy" "waf" {
  depends_on = [module.resource_group]

  resource_group_name = local.resource_group_name
  location            = var.region
  name                = "waf-policy"

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
  policy_settings {
    enabled                     = true
    mode                        = "Detection"
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
    request_body_check          = true
  }
}

#---------------------------------------
# Application gateway for the Quality Manager app
# To make quality manager Azure Entra authentication work, the backend pool must use https, and the probe 
# must also be configured to check the https endpoint. We do not do https termination on the application gateway.
#---------------------------------------
module "application_gateway_qm" {
  depends_on = [module.app_service_qm]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-application-gateway?ref=v0.0.5"

  azure_appgateway_resource_group_name = local.resource_group_name
  region                               = var.region
  azure_appgateway_tags = merge(
    local.common_tags,
    var.azure_appgateway_tags != null ? var.azure_appgateway_tags : {}
  )
  azure_appgateway_name                              = var.azure_appgateway_name
  azure_appgateway_fips_enabled                      = var.azure_appgateway_fips_enabled
  azure_appgateway_zones                             = var.azure_appgateway_zones
  azure_appgateway_enable_http2                      = var.azure_appgateway_enable_http2
  azure_appgateway_force_firewall_policy_association = true
  azure_appgateway_firewall_policy_id                = azurerm_web_application_firewall_policy.waf.id
  azure_appgateway_authentication_certificate        = var.azure_appgateway_authentication_certificate
  azure_appgateway_trusted_root_certificate          = var.azure_appgateway_trusted_root_certificate
  azure_appgateway_ssl_certificate = [
    {
      name                = "appgateway_ssl_certificate"
      data                = var.azure_appgateway_certificate_pfx != null ? filebase64(var.azure_appgateway_certificate_pfx) : null
      password            = var.azure_appgateway_certificate_password
      key_vault_secret_id = var.azure_appgateway_certificate_key_vault_secret_id
    }
  ]
  azure_appgateway_sku = var.azure_appgateway_sku
  azure_appgateway_gateway_ip_configuration = [
    {
      name      = "appgateway_gateway_ip_configuration"
      subnet_id = module.subnet_agw.subnet_id
    }
  ]
  azure_appgateway_frontend_port = [
    {
      name = "appgateway_frontend_https_port"
      port = 443
    }
  ]
  azure_appgateway_frontend_ip_configuration = [
    {
      name                            = "appgateway_frontend_ip_configuration"
      public_ip_address_id            = module.public_ip_agw.public_ip_id
      subnet_id                       = null
      private_ip_address              = null
      private_ip_address_allocation   = null
      private_link_configuration_name = null
    }
  ]
  azure_appgateway_backend_address_pool = [
    {
      name         = "appgateway_backend_address_pool"
      fqdns        = ["${data.azurerm_windows_web_app.qm.default_hostname}"]
      ip_addresses = []
    }
  ]
  azure_appgateway_backend_http_settings = [
    {
      name                                = "appgateway_backend_https_settings"
      cookie_based_affinity               = "Disabled"
      path                                = null
      port                                = 443
      protocol                            = "Https"
      request_timeout                     = 60
      affinity_cookie_name                = null
      probe_name                          = "appgateway_backend_probe"
      host_name                           = null
      pick_host_name_from_backend_address = false
      trusted_root_certificate_names      = []
      authentication_certificate          = []
      connection_draining                 = []
    }
  ]
  azure_appgateway_http_listener = [
    {
      name                           = "appgateway_https_listener"
      frontend_ip_configuration_name = "appgateway_frontend_ip_configuration"
      frontend_port_name             = "appgateway_frontend_https_port"
      protocol                       = "Https"
      host_name                      = null
      host_names                     = []
      require_sni                    = null
      ssl_certificate_name           = "appgateway_ssl_certificate"
      firewall_policy_id             = null
      ssl_profile_name               = null
      custom_error_configuration     = []
    }
  ]
  azure_appgateway_identity                   = var.azure_appgateway_identity
  azure_appgateway_private_link_configuration = var.azure_appgateway_private_link_configuration
  azure_appgateway_probe = [
    {
      host                                      = "${data.azurerm_windows_web_app.qm.default_hostname}"
      interval                                  = var.azure_appgateway_probe_interval
      name                                      = "appgateway_backend_probe"
      protocol                                  = "Https"
      path                                      = "/qualitymanager"
      timeout                                   = var.azure_appgateway_probe_timeout
      unhealthy_threshold                       = var.azure_appgateway_probe_unhealthy_threshold
      port                                      = 443
      pick_host_name_from_backend_http_settings = false
      minimum_servers                           = null
      match = [
        {
          status_code = ["200-401"]
          body        = null
        }
      ]
    }
  ]
  azure_appgateway_request_routing_rule = [
    {
      name                        = "appgateway_request_routing_rule"
      priority                    = 100
      rule_type                   = "Basic"
      http_listener_name          = "appgateway_https_listener"
      backend_address_pool_name   = "appgateway_backend_address_pool"
      backend_http_settings_name  = "appgateway_backend_https_settings"
      redirect_configuration_name = null
      rewrite_rule_set_name       = "quality-manager-rewrite-rule-set"
      url_path_map_name           = null
    }
  ]
  azure_appgateway_global                  = var.azure_appgateway_global
  azure_appgateway_url_path_map            = var.azure_appgateway_url_path_map
  azure_appgateway_ssl_profile             = var.azure_appgateway_ssl_profile
  azure_appgateway_ssl_policy              = var.azure_appgateway_ssl_policy
  azure_appgateway_waf_configuration       = var.azure_appgateway_waf_configuration
  azure_appgateway_redirect_configuration  = var.azure_appgateway_redirect_configuration
  azure_appgateway_autoscale_configuration = var.azure_appgateway_autoscale_configuration
  azure_appgateway_rewrite_rule_set = concat(
    var.azure_appgateway_rewrite_rule_set, [{
      name = "quality-manager-rewrite-rule-set"
      rule = [{
        name          = "root_2_quality_manager"
        rule_sequence = 100
        condition = [{
          variable    = "var_uri_path"
          pattern     = "^/$"
          ignore_case = true
          negate      = false
        }]
        request_header_configuration  = []
        response_header_configuration = []
        url = [{
          path         = "/qualitymanager"
          reroute      = false
          query_string = null
          components   = "path_only"
        }]
      }]
    }]
  )
}

resource "azurerm_monitor_diagnostic_setting" "waf_diag_setting" {
  name               = "app-gateway-firewall-logging"
  target_resource_id = module.application_gateway_qm.azure_appgateway_id
  storage_account_id = module.storage_account.storage_account_id

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }
}

resource "null_resource" "application_gateway_qm_dns_record" {
  # Conditional deployment of dns record for the app service
  count      = var.windows_appservice_dns_zone_registration ? 1 : 0
  depends_on = [module.application_gateway_qm, azurerm_app_service_certificate_binding.qm]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = <<EOF
      az login --service-principal -u $env:ARM_CLIENT_ID -p $env:ARM_CLIENT_SECRET --tenant $env:ARM_TENANT_ID
      az network dns record-set cname set-record --resource-group ${var.windows_appservice_dns_zone_resource_group} --zone-name ${var.windows_appservice_dns_zone_name} --record-set-name ${var.windows_appservice_custom_hostname} --cname ${module.public_ip_agw.public_ip_fqdn}
    EOF
    interpreter = ["PowerShell", "-Command"]
  }
}

# TODO Integration Mdm with private end point for security and performance
# data "azurerm_linux_web_app" "md_api" {
#   name                = var.regn_md_master_data_api_name
#   resource_group_name = var.regn_md_master_data_api_resource_group_name
# }

# TODO Integration Mdm with private end point for security and performance
# Private endpoint for the master data api in the backend(db) VNet, this is entry point for Data integration function to access the master data api privately
# module "private_endpoint_md_api" {
#   source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-private-endpoint?ref=v0.0.1"

#   pep_resource_group_name = local.resource_group_name
#   region                  = var.region
#   pep_tags = (
#     var.pep_tags_md_api == null
#     ? var.common_tags
#     : var.pep_tags_md_api
#   )

#   pep_name                 = var.pep_name_md_api
#   pep_subnet_id            = module.subnet_pep_md_api.subnet_id
#   pep_psc_name             = "qm_app_to_master_data_api"
#   pep_resource_id          = data.azurerm_linux_web_app.md_api.id
#   pep_subresource_names    = "sites"
#   pep_is_manual_connection = false
#   pep_private_dns_zone_group = [{
#     pep_private_dns_zone_group_name = "qm.privatelink.azurewebsites.net"
#     pep_private_dns_zone_ids        = [azurerm_private_dns_zone.qm.id]
#   }]
# }


# Application insight for the Data Integration function app
module "app_insight_di_func" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-applicationinsight?ref=v0.0.1"

  application_insight_resource_group_name = local.resource_group_name
  region                                  = var.region
  application_insight_tags = merge(
    local.common_tags,
    var.difunc_application_insight_tags != null ? var.difunc_application_insight_tags : {}
  )

  application_insight_name                                  = var.difunc_application_insight_name
  application_insight_workspace_id                          = data.azurerm_log_analytics_workspace.log_analytics_workspace.id
  application_insight_application_type                      = "web"
  application_insight_daily_data_cap_in_gb                  = var.difunc_application_insight_daily_data_cap_in_gb
  application_insight_daily_data_cap_notifications_disabled = var.difunc_application_insight_daily_data_cap_notifications_disabled
  application_insight_retention_in_days                     = var.difunc_application_insight_retention_in_days
  application_insight_sampling_percentage                   = var.difunc_application_insight_sampling_percentage
  application_insight_disable_ip_masking                    = var.difunc_application_insight_disable_ip_masking
  application_insight_local_authentication_disabled         = var.difunc_application_insight_local_authentication_disabled
  application_insight_internet_ingestion_enabled            = var.difunc_application_insight_internet_ingestion_enabled
  application_insight_internet_query_enabled                = var.difunc_application_insight_internet_query_enabled
  application_insight_force_customer_storage_for_profiler   = var.difunc_application_insight_force_customer_storage_for_profiler
}

# App service plan for the Data Integration function app
module "app_service_plan_di_func" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-app-service-plan?ref=v0.0.2"

  app_service_plan_resource_group_name = local.resource_group_name
  region                               = var.region
  app_service_plan_tags = merge(
    local.common_tags,
    var.difunc_app_service_plan_tags != null ? var.difunc_app_service_plan_tags : {}
  )

  app_service_plan_name                         = var.difunc_app_service_plan_name
  app_service_plan_os_type                      = var.difunc_app_service_plan_os_type
  app_service_plan_sku_name                     = var.difunc_app_service_plan_sku_name
  app_service_plan_app_service_environment_id   = var.difunc_app_service_plan_app_service_environment_id
  app_service_plan_maximum_elastic_worker_count = var.difunc_app_service_plan_maximum_elastic_worker_count
  app_service_plan_per_site_scaling_enabled     = var.difunc_app_service_plan_per_site_scaling_enabled
  app_service_plan_worker_count                 = var.difunc_app_service_plan_worker_count
  app_service_plan_zone_balancing_enabled       = var.difunc_app_service_plan_zone_balancing_enabled
}

module "servicebus_namespace" {
  depends_on = [module.resource_group]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-service-bus//modules/servicebus_namespace?ref=v0.0.1"

  azure_service_bus_namespace_resource_group_name = local.resource_group_name
  region                                          = var.region
  azure_service_bus_namespace_name                = var.servicebus_namespace_name
  azure_service_bus_namespace_sku                 = var.servicebus_namespace_sku
  azure_service_bus_namespace_tags = merge(
    local.common_tags,
    var.servicebus_namespace_tags != null ? var.servicebus_namespace_tags : {}
  )

  azure_service_bus_namespace_capacity                      = var.servicebus_namespace_capacity
  azure_service_bus_namespace_premium_messaging_partitions  = var.servicebus_namespace_premium_messaging_partitions
  azure_service_bus_namespace_local_auth_enabled            = var.servicebus_namespace_local_auth_enabled
  azure_service_bus_namespace_public_network_access_enabled = var.servicebus_namespace_public_network_access_enabled
  azure_service_bus_namespace_minimum_tls_version           = var.servicebus_namespace_minimum_tls_version
  azure_service_bus_namespace_zone_redundant                = var.servicebus_namespace_zone_redundant
  azure_service_bus_namespace_identity_type                 = var.servicebus_namespace_identity_type
  azure_service_bus_namespace_identity_ids                  = var.servicebus_namespace_identity_ids
  azure_service_bus_namespace_network_rule_set              = var.servicebus_namespace_network_rule_set
  azure_service_bus_namespace_customer_managed_keys         = var.servicebus_namespace_customer_managed_keys
}

module "servicebus_topic" {
  depends_on = [module.servicebus_namespace]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-service-bus//modules/servicebus_topic?ref=v0.0.1"

  azure_service_bus_topic_name                                    = var.servicebus_topic_name
  azure_service_bus_namespace_id                                  = module.servicebus_namespace.service_bus_namespace_id
  azure_service_bus_topic_enable_partitioning                     = var.servicebus_topic_enable_partitioning
  azure_service_bus_topic_status                                  = var.servicebus_topic_status
  azure_service_bus_topic_auto_delete_on_idle                     = var.servicebus_topic_auto_delete_on_idle
  azure_service_bus_topic_default_message_ttl                     = var.servicebus_topic_default_message_ttl
  azure_service_bus_topic_duplicate_detection_history_time_window = var.servicebus_topic_duplicate_detection_history_time_window
  azure_service_bus_topic_enable_batched_operations               = var.servicebus_topic_enable_batched_operations
  azure_service_bus_topic_enable_express                          = var.servicebus_topic_enable_express
  azure_service_bus_topic_max_message_size_in_kilobytes           = var.servicebus_topic_max_message_size_in_kilobytes
  azure_service_bus_topic_max_size_in_megabytes                   = var.servicebus_topic_max_size_in_megabytes
  azure_service_bus_topic_requires_duplicate_detection            = var.servicebus_topic_requires_duplicate_detection
  azure_service_bus_topic_support_ordering                        = var.servicebus_topic_support_ordering
}

module "servicebus_topic_authorization_rule" {
  depends_on = [module.servicebus_topic]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-service-bus//modules/servicebus_topic_authorization_rule?ref=v0.0.1"

  azure_servicebus_topic_authorization_rule_name     = var.servicebus_topic_authorization_rule_name
  azure_servicebus_topic_authorization_rule_topic_id = module.servicebus_topic.topic_id
  azure_servicebus_topic_authorization_rule_listen   = var.servicebus_topic_authorization_rule_listen
  azure_servicebus_topic_authorization_rule_send     = var.servicebus_topic_authorization_rule_send
  azure_servicebus_topic_authorization_rule_manage   = var.servicebus_topic_authorization_rule_manage
}

module "servicebus_queue" {
  depends_on = [module.servicebus_namespace]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-service-bus//modules/servicebus_queue?ref=v0.0.1"

  azure_service_bus_queue_name                                    = var.servicebus_queue_name
  azure_service_bus_queue_namespace_id                            = module.servicebus_namespace.service_bus_namespace_id
  azure_service_bus_queue_enable_partitioning                     = var.servicebus_queue_enable_partitioning
  azure_service_bus_queue_lock_duration                           = var.servicebus_queue_lock_duration
  azure_service_bus_queue_max_message_size_in_kilobytes           = var.servicebus_queue_max_message_size_in_kilobytes
  azure_service_bus_queue_max_size_in_megabytes                   = var.servicebus_queue_max_size_in_megabytes
  azure_service_bus_queue_requires_duplicate_detection            = var.servicebus_queue_requires_duplicate_detection
  azure_service_bus_queue_requires_session                        = var.servicebus_queue_requires_session
  azure_service_bus_queue_default_message_ttl                     = var.servicebus_queue_default_message_ttl
  azure_service_bus_queue_dead_lettering_on_message_expiration    = var.servicebus_queue_dead_lettering_on_message_expiration
  azure_service_bus_queue_duplicate_detection_history_time_window = var.servicebus_queue_duplicate_detection_history_time_window
  azure_service_bus_queue_max_delivery_count                      = var.servicebus_queue_max_delivery_count
  azure_service_bus_queue_status                                  = var.servicebus_queue_status
  azure_service_bus_queue_enable_batched_operations               = var.servicebus_queue_enable_batched_operations
  azure_service_bus_queue_auto_delete_on_idle                     = var.servicebus_queue_auto_delete_on_idle
  azure_service_bus_queue_forward_dead_lettered_messages_to       = var.servicebus_queue_forward_dead_lettered_messages_to
}

module "servicebus_queue_authorization_rule" {
  depends_on = [module.servicebus_queue]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-service-bus//modules/servicebus_queue_authorization_rule?ref=v0.0.1"

  azure_servicebus_queue_authorization_rule_name         = var.servicebus_queue_authorization_rule_name
  azure_servicebus_queue_authorization_rule_namespace_id = module.servicebus_queue.azure_servicebus_queue_id
  azure_servicebus_queue_authorization_rule_listen       = var.servicebus_queue_authorization_rule_listen
  azure_servicebus_queue_authorization_rule_send         = var.servicebus_queue_authorization_rule_send
  azure_servicebus_queue_authorization_rule_manage       = var.servicebus_queue_authorization_rule_manage
}

module "servicebus_subscription_qm" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-service-bus//modules/servicebus_subscription?ref=v0.0.1"

  azure_service_bus_subscription_name                                      = var.difunc_servicebus_subscription_name
  azure_service_bus_topic_id                                               = module.servicebus_topic.topic_id
  azure_service_bus_subscription_max_delivery_count                        = var.difunc_servicebus_subscription_max_delivery_count
  azure_service_bus_subscription_auto_delete_on_idle                       = var.difunc_servicebus_subscription_auto_delete_on_idle
  azure_service_bus_subscription_default_message_ttl                       = var.difunc_servicebus_subscription_default_message_ttl
  azure_service_bus_subscription_lock_duration                             = var.difunc_servicebus_subscription_lock_duration
  azure_service_bus_subscription_dead_lettering_on_message_expiration      = var.difunc_servicebus_subscription_dead_lettering_on_message_expiration
  azure_service_bus_subscription_dead_lettering_on_filter_evaluation_error = var.difunc_servicebus_subscription_dead_lettering_on_filter_evaluation_error
  azure_service_bus_subscription_enable_batched_operations                 = var.difunc_servicebus_subscription_enable_batched_operations
  azure_service_bus_subscription_requires_session                          = var.difunc_servicebus_subscription_requires_session
  azure_service_bus_subscription_forward_to                                = var.difunc_servicebus_subscription_forward_to
  azure_service_bus_subscription_forward_dead_lettered_messages_to         = var.difunc_servicebus_subscription_forward_dead_lettered_messages_to
  azure_service_bus_subscription_status                                    = var.difunc_servicebus_subscription_status
  azure_service_bus_subscription_client_scoped_subscription                = var.difunc_servicebus_subscription_client_scoped_subscription
}

module "servicebus_subscription_rule_qm" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-service-bus//modules/servicebus_subscription_rule?ref=v0.0.1"

  azure_service_bus_subscription_rule_name               = var.difunc_servicebus_subscription_rule_name
  azure_service_bus_subscription_id                      = module.servicebus_subscription_qm.subscription_id
  azure_service_bus_subscription_rule_filter_type        = var.difunc_servicebus_subscription_rule_filter_type
  azure_service_bus_subscription_rule_sql_filter         = var.difunc_servicebus_subscription_rule_sql_filter
  azure_service_bus_subscription_rule_action             = var.difunc_servicebus_subscription_rule_action
  azure_service_bus_subscription_rule_correlation_filter = var.difunc_servicebus_subscription_rule_correlation_filter
}

data "azurerm_iothub" "regn_msg_rcp" {
  name                = var.regn_msg_reception_iot_hub_name
  resource_group_name = var.regn_msg_reception_resource_group_name
}

#---------------------------------------
# Iothub device state queue endpoint
#---------------------------------------
// TODO request for IT module and replace this when it is done
// Identity based service bus queue access does not work, so use the connection string
resource "azurerm_iothub_endpoint_servicebus_queue" "state_queue" {
  depends_on = [module.servicebus_queue]

  resource_group_name = local.resource_group_name
  name                = "device-qm-state-queue-endpoint"
  iothub_id           = data.azurerm_iothub.regn_msg_rcp.id
  connection_string   = module.servicebus_queue_authorization_rule.servicebus_queue_authorization_rule_primary_connection_string
}

#---------------------------------------
# Iothub data message service bus topic endpoint
#---------------------------------------
// TODO request for IT module and replace this when it is done
// Identity based service bus queue access does not work, so use the connection string
resource "azurerm_iothub_endpoint_servicebus_topic" "qm_data_topic" {
  depends_on = [module.servicebus_topic]

  resource_group_name = local.resource_group_name
  name                = "device-qm-data-topic-endpoint"
  iothub_id           = data.azurerm_iothub.regn_msg_rcp.id
  connection_string   = module.servicebus_topic_authorization_rule.servicebus_topic_authorization_rule_primary_connection_string
}

#---------------------------------------
# Iothub device state queue route
#---------------------------------------
module "iothub_route_device_state_queue" {
  depends_on = [azurerm_iothub_endpoint_servicebus_queue.state_queue]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-iot-hub//modules/IotHub_route?ref=v0.0.2"

  azure_iothub_route_resource_group_name = var.regn_msg_reception_resource_group_name
  azure_iothub_route_iothub_name         = var.regn_msg_reception_iot_hub_name
  azure_iothub_route_name                = "device-qm-state-queue-route"
  azure_iothub_route_source              = "DeviceConnectionStateEvents"
  azure_iothub_route_condition           = "true"
  azure_iothub_route_endpoint_names      = ["device-qm-state-queue-endpoint"]
  azure_iothub_route_enabled             = true
}

#---------------------------------------
# Iothub device data topic route
#---------------------------------------
module "iothub_route_device_data_topic" {
  depends_on = [azurerm_iothub_endpoint_servicebus_topic.qm_data_topic]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-iot-hub//modules/IotHub_route?ref=v0.0.2"

  azure_iothub_route_resource_group_name = var.regn_msg_reception_resource_group_name
  azure_iothub_route_iothub_name         = var.regn_msg_reception_iot_hub_name
  azure_iothub_route_name                = "device-qm-data-topic-route"
  azure_iothub_route_source              = "DeviceMessages"
  azure_iothub_route_condition           = "is_defined($body.IotGwMetaData.MessageType) AND $body.IotGwMetaData.MessageType = 0 AND is_defined($body.IotGwMetaData.ClientType) AND $body.IotGwMetaData.ClientType <> 'AQURE' AND is_defined($body.DeviceMetaData.PayLoadDataType) AND ($body.DeviceMetaData.PayLoadDataType = 'DeviceStatus' OR $body.DeviceMetaData.PayLoadDataType = 'QCResult' OR $body.DeviceMetaData.PayLoadDataType = 'ParameterStatus')"
  azure_iothub_route_endpoint_names      = ["device-qm-data-topic-endpoint"]
  azure_iothub_route_enabled             = true
}

# Storage file share for the Data integration, as the entry point for configuration files
module "storage_account_fileshare_di_func" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-storage//modules/file_share?ref=v0.0.7"

  storage_fileshare_name                 = var.storage_fileshare_name_di_func
  storage_fileshare_storage_account_name = module.storage_account.storage_account_name
  storage_fileshare_quota                = var.storage_fileshare_quota_di_func
  storage_fileshare_access_tier          = var.storage_fileshare_access_tier_di_func
  storage_fileshare_enabled_protocol     = var.storage_fileshare_enabled_protocol_di_func
  storage_fileshare_metadata             = var.storage_fileshare_metadata_di_func
  storage_fileshare_acls                 = var.storage_fileshare_acls_di_func
}

module "storage_share_file_di_func_parameter_mappings" {
  depends_on = [module.storage_account_fileshare_di_func]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-storage//modules/storage_share_file?ref=v0.0.7"

  storage_share_file_name             = "ParameterMappings.json"
  storage_share_file_storage_share_id = module.storage_account_fileshare_di_func.storage_share_id
  storage_share_file_source           = "${path.module}/settings/ParameterMappings.json"
  storage_share_file_content_md5      = filemd5("${path.module}/settings/ParameterMappings.json")
}

// TODO request for IT module and replace this when it is done
resource "azurerm_storage_table" "di_func_device_status" {
  name                 = "DeviceStatus"
  storage_account_name = module.storage_account.storage_account_name
}

data "azurerm_servicebus_namespace" "qm" {
  depends_on          = [module.servicebus_namespace]
  name                = var.servicebus_namespace_name
  resource_group_name = local.resource_group_name
}

# Function app for the Data Integration function
module "func_app_data_integration" {
  depends_on = [module.app_service_plan_di_func, module.storage_account, module.servicebus_subscription_qm]
  source     = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-linux-funcapp?ref=v0.0.8"

  linux_funcapp_resource_group_name = local.resource_group_name
  region                            = var.region
  linux_funcapp_tags = merge(
    local.common_tags,
    var.difunc_linux_funcapp_tags != null ? var.difunc_linux_funcapp_tags : {}
  )

  linux_funcapp_name                 = var.difunc_linux_funcapp_name
  linux_funcapp_DeployStorageAccount = false
  linux_funcapp_GetStorageAccountKey = false
  linux_funcapp_AzStorageName        = module.storage_account.storage_account_name
  linux_funcapp_storageaccount_key   = data.azurerm_storage_account.qm.primary_access_key
  linux_funcapp_service_plan_id      = module.app_service_plan_di_func.app_service_plan_id
  linux_funcapp_app_settings = merge(
    var.difunc_linux_funcapp_app_settings,
    {
      DIFuncOptions__SvcBusConnStr             = data.azurerm_servicebus_namespace.qm.default_primary_connection_string
      DIFuncOptions__TopicName                 = var.servicebus_topic_name
      DIFuncOptions__SubscriptionName          = var.difunc_servicebus_subscription_name
      DIFuncOptions__QueueName                 = var.servicebus_queue_name
      DIFuncOptions__TableStorageUrl           = "https://${module.storage_account.storage_account_name}.table.core.windows.net/DeviceStatus"
      WEBSITE_CLOUD_ROLENAME                   = "DataIntegrationFunction"
      DIFuncOptions__MasterDataApiClientId     = var.mdm_app_client_id
      DIFuncOptions__MasterDataApiTenantId     = var.mdm_app_tenant_id
      DIFuncOptions__MasterDataApiClientSecret = var.mdm_app_client_secret
      DIFuncOptions__MasterDataApiBaseUrl      = var.mdm_api_base_url
      DIFuncOptions__MasterDataApiDataFilter   = "Region/Code eq '${var.mdm_region_code}'"
    }
  )
  linux_funcapp_client_certificate_enabled             = var.difunc_linux_funcapp_client_certificate_enabled
  linux_funcapp_client_certificate_mode                = var.difunc_linux_funcapp_client_certificate_mode
  linux_funcapp_client_certificate_exclusion_paths     = var.difunc_linux_funcapp_client_certificate_exclusion_paths
  linux_funcapp_builtin_logging_enabled                = var.difunc_linux_funcapp_builtin_logging_enabled
  linux_funcapp_virtual_network_subnet_id              = module.subnet_di.subnet_id
  linux_funcapp_https_only                             = var.difunc_linux_funcapp_https_only
  linux_funcapp_vnet_route_all_enabled                 = var.difunc_linux_funcapp_vnet_route_all_enabled
  linux_funcapp_http2_enabled                          = var.difunc_linux_funcapp_http2_enabled
  linux_funcapp_always_on                              = var.difunc_linux_funcapp_always_on
  linux_funcapp_application_insights_connection_string = module.app_insight_di_func.application_insight_cnnection_string
  linux_funcapp_dotnet_version                         = var.difunc_linux_funcapp_dotnet_version
  linux_funcapp_use_dotnet_isolated_runtime            = var.difunc_linux_funcapp_use_dotnet_isolated_runtime
  linux_funcapp_java_version                           = var.difunc_linux_funcapp_java_version
  linux_funcapp_node_version                           = var.difunc_linux_funcapp_node_version
  linux_funcapp_powershell_core_version                = var.difunc_linux_funcapp_powershell_core_version
  linux_funcapp_python_version                         = var.difunc_linux_funcapp_python_version
  linux_funcapp_use_custom_runtime                     = var.difunc_linux_funcapp_use_custom_runtime
  linux_funcapp_enable_cors                            = var.difunc_linux_funcapp_enable_cors
  linux_funcapp_allowed_origins                        = var.difunc_linux_funcapp_allowed_origins
  linux_funcapp_support_credentials                    = var.difunc_linux_funcapp_support_credentials
  linux_funcapp_public_network_access_enabled          = var.difunc_linux_funcapp_public_network_access_enabled
  linux_funcapp_ip_restrictions                        = var.difunc_linux_funcapp_ip_restrictions
  linux_funcapp_ip_restriction_default_action          = var.difunc_linux_funcapp_ip_restriction_default_action
  linux_funcapp_scm_use_main_ip_restriction            = var.difunc_linux_funcapp_scm_use_main_ip_restriction
  linux_funcapp_scm_ip_restrictions                    = var.difunc_linux_funcapp_scm_ip_restrictions
  linux_funcapp_scm_ip_restriction_default_action      = var.difunc_linux_funcapp_scm_ip_restriction_default_action
  linux_funcapp_identity_type                          = var.difunc_linux_funcapp_identity_type
  linux_funcapp_identity_ids                           = var.difunc_linux_funcapp_identity_ids
  linux_funcapp_auth_settings                          = var.difunc_linux_funcapp_auth_settings
  linux_funcapp_health_check_path                      = "/api/health"
  linux_funcapp_health_check_eviction_time_in_min      = var.difunc_linux_funcapp_health_check_eviction_time_in_min
  linux_funcapp_storage_account = [{
    name         = "di-func-data"
    account_name = module.storage_account.storage_account_name
    share_name   = var.storage_fileshare_name_di_func
    access_key   = data.azurerm_storage_account.qm.primary_access_key //TODO when AzureRm support managed identity without access_key, replace this
    type         = "AzureFiles"
    mount_path   = "/AppData"
  }]

  linux_funcapp_storage_account_name     = null
  linux_funcapp_account_tier             = null
  linux_funcapp_account_replication_type = null
  AzUsername                             = null
  AzPassword                             = null
  AzTenantId                             = null
  AzSubscriptionId                       = null
  linux_funcapp_AzStorageRG              = null
}

# Role assignment for the data integration function app managed identity to access the storage account table
module "role_assignment_difunc_to_storage" {
  source = "git::https://#{lib_repo_access_token}#@dev.azure.com/RadiometerGIT/rmg-git-terraform-modules/_git/terraform-azurerm-role-management//modules/role_assignment?ref=v0.0.2"

  role_assignment_scope                = module.storage_account.storage_account_id
  role_assignment_role_definition_name = "Storage Table Data Contributor"
  role_assignment_principal_id         = module.func_app_data_integration.function_app_principal_id
  role_assignment_description          = "Read access to storage account for VM"
}

#---------------------------------------
# Script that registers the Quality manager url to Master data management
#---------------------------------------
resource "null_resource" "register_regional_qm_url_to_mdm" {
  depends_on = [module.application_gateway_qm]

  triggers = {
    always_run = "${timestamp()}"
    # qm_url = "${var.windows_appservice_custom_hostname}.${var.windows_appservice_dns_zone_name}" # execute only if regional QM url changes
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/scripts/register.mdm.ext.prop.ps1", {
      MdmTenantId         = var.mdm_app_tenant_id
      MdmClientId         = var.mdm_app_client_id
      MdmClientSecret     = var.mdm_app_client_secret
      MdmApiBaseUrl       = var.mdm_api_base_url
      RegionCode          = var.mdm_region_code
      ExtensionFieldName  = "QualityManagerUrl"
      ExtensionFieldValue = "https://${var.windows_appservice_custom_hostname}.${var.windows_appservice_dns_zone_name}"
    })
    interpreter = ["PowerShell", "-Command"]
  }
}

#---------------------------------------
# Script that registers the Quality manager application and roles to Master data management
#---------------------------------------
resource "null_resource" "register_regional_qm_app_roles_to_mdm" {
  depends_on = [module.application_gateway_qm]

  triggers = {
    always_run = "${timestamp()}"
    # qm_groups = "${var.regn_qm_nimbus_basic_user_group_id}.${var.regn_qm_admin_user_group_id}"
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/scripts/register.mdm.app.roles.ps1", {
      MdmTenantId        = var.mdm_app_tenant_id
      MdmClientId        = var.mdm_app_client_id
      MdmClientSecret    = var.mdm_app_client_secret
      MdmApiBaseUrl      = var.mdm_api_base_url
      RegionCode         = var.mdm_region_code
      NimbusBasicGroupId = var.regn_qm_nimbus_basic_user_group_id
      AdminGroupId       = var.regn_qm_admin_user_group_id
    })
    interpreter = ["PowerShell", "-Command"]
  }
}

# Azure monitor workbook for Regional Quality manager component / TODO request for IT module and replace this when it is done
resource "azurerm_application_insights_workbook" "regn_qm_workbook" {
  resource_group_name = local.resource_group_name
  location            = var.region
  tags = merge(
    local.common_tags,
    var.regn_qm_application_insights_workbook_tags != null ? var.regn_qm_application_insights_workbook_tags : {}
  )

  name         = var.regn_qm_application_insights_workbook_name
  display_name = var.regn_qm_application_insights_workbook_display_name
  data_json = jsonencode(templatefile("${path.module}/workbooks/regional.qm.json", {
    applicationGatewayResourceId      = module.application_gateway_qm.azure_appgateway_id,
    difuncAppServicePlanResourceId    = module.app_service_plan_di_func.app_service_plan_id,
    difuncAppResourceId               = module.func_app_data_integration.function_app_id,
    difuncAppInsightResourceId        = module.app_insight_di_func.application_insight_id,
    qmAppServicePlanResourceId        = module.app_service_plan_qm.app_service_plan_id,
    qmAppInsightResourceId            = module.app_insight_qm_app.application_insight_id,
    qmDbServerResourceId              = module.db_vm.virtual_machine_id,
    qmLogAnalyticsWorkspaceResourceId = data.azurerm_log_analytics_workspace.log_analytics_workspace.id,
    functionPrefix                    = var.traffic_light_func_prefix,
    functionDuration                  = var.traffic_light_workbook_function_time_parameter
  }))
}

# POC Monitoring module
module "monitoring" {
  source     = "git::https://#{tfs_repo_access_token}#@tfs.radiometer.net/tfs/ITS/Radiometer%20Connect/_git/InfraAsCode//TerraformModules/TrafficLightMonitoringFunctions?ref=v0.0.7"
  depends_on = [module.resource_group]

  resource_group_name        = local.resource_group_name
  location                   = var.region
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.log_analytics_workspace.id

  # Function config
  traffic_light_function_prefix           = var.traffic_light_func_prefix
  traffic_light_config_azuremetrics_table = var.traffic_light_config_azuremetrics_table
  traffic_light_config_perf_table         = local.local_traffic_light_config_perf_table
  traffic_light_config_appmetrics_table   = local.local_traffic_light_config_appmetrics_table
  traffic_light_config_apptraces_table    = local.local_traffic_light_config_apptraces_table

  # Enable Metrics emitting
  resources_with_enabled_diagnostic_settings = local.resources_with_enabled_diagnostic_settings

  include_azure_metrics = true
  include_perf_metrics  = true
  include_app_metrics   = true
  include_app_traces    = true

  # Enable emitting Metrics for VM
  dcr_performance_counter_specifiers = var.dcr_performance_counter_specifiers
  vm_name                            = module.db_vm.windows_virtual_machine_name
  vm_id                              = module.db_vm.virtual_machine_id
  dcr_stream_names                   = ["Microsoft-Perf"]

  # Action group config
  action_group_ids = var.action_group_ids

  # Config for alerting timeframe
  traffic_light_alert_frequency               = var.traffic_light_alert_frequency
  traffic_light_alert_time_window             = var.traffic_light_alert_time_window
  traffic_light_alert_function_time_parameter = var.traffic_light_alert_function_time_parameter
}

