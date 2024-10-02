targetScope = 'subscription'

param location string = deployment().location

@maxLength(10)
@description('''Identifier used to describe the business unit (or customer) utilizing AVD images in your tenant.
If not specified then centralized AVD Management is assumed and resources and resource groups are named accordingly.
If this is specified, then the "centralizedImageManagement" parameter determines how resources are organized and deployed.
''')
param businessUnitIdentifier string = ''

@description('''Optional. When the "businessUnitIdentifier" parameter is not empty, this parameter determines if the Image Management Resource Group and associated resources
are created in a centralized resource group (does not include "businessUnitIdentifier" in the name) and management resources are named accordingly or if a Business unit
specific image management resource group is created and management resources are named accordingly.
If the "businessUnitIdentifier" parameter is left empty ("") then this value has no effect.
''')
param centralizedImageManagement bool = false

@description('Optional. Reverse the normal Cloud Adoption Framework naming convention by putting the resource type abbreviation at the end of the resource name.')
param nameConvResTypeAtEnd bool = false

@description('Optional. The custom name of the Image Gallery to Deploy.')
@minLength(3)
@maxLength(128)
param customComputeGalleryName string = 'none'

@minLength(3)
@maxLength(128)
@description('Optional. The name of the User Assigned Managed Identity that will be created and granted Storage Blob Data Reader Rights to the storage account for the Packer/Image Builder VMs.')
param customManagedIdentityName string = 'none'

@minLength(3)
@maxLength(63)
@description('Optional. The resource group name where the Storage Account will be created. It will be created if it does not exist.')
param customResourceGroupName string = 'none'

@minLength(3)
@maxLength(24)
@description('Optional. The name of the storage account to deploy. Must be at least 3 characters long. Should follow CAF naming conventions.')
param customArtifactsStorageAccountName string = 'none'

@minLength(3)
@maxLength(63)
@description('Optional. Blob Container Name. Must start with a letter. Can only contain lower case letters, numbers, and -.')
param artifactsContainerName string = 'artifacts'

@description('Optional. Resource Id of an existing Log Analytics Workspace to which diagnostic logs will be sent.')
param logAnalyticsWorkspaceResourceId string = ''

@allowed([
  'd'
  't'
  'p'
  ''
])
@description('Optional. The environment for which image management is being deployed. "d" = Development, "t" = Test, and "p" = Production. Leave blank to eliminate this field from the naming convention.')
param envShortName string = ''

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
@description('Optional. Storage Account Sku Name.')
param storageSkuName string = 'Standard_LRS'

@allowed([
  'Premium'
  'Hot'
  'Cool'
])
@description('Conditional. Required if the Storage Account kind is set to BlobStorage. The access tier is used for billing. The "Premium" access tier is the default value for premium block blobs storage account type and it cannot be changed for the premium block blobs storage account type.')
param storageAccessTier string = 'Hot'

@description('Optional. Indicates whether the storage account permits requests to be authorized with the account access key via Shared Key. If false, then all requests, including shared access signatures, must be authorized with Azure Active Directory (Azure AD). The default value is null, which is equivalent to true.')
param storageAllowSharedKeyAccess bool = true

@description('Optional. The SAS expiration period. DD.HH:MM:SS.')
param storageSASExpirationPeriod string = '180.00:00:00'

@description('Optional. The Resource Id of the Private DNS Zone where the Private Endpoint (if configured) A record will be registered.')
param azureBlobPrivateDnsZoneResourceId string = ''

@description('Optional. Whether or not public network access is allowed for this resource. To limit public network access, use the "PermittedIPs" and/or the "ServiceEndpointSubnetResourceIds" parameters.')
@allowed([
  'Enabled'
  'Disabled'
])
param storagePublicNetworkAccess string = 'Enabled'

@description('Optional. The ResourceId of the private endpoint subnet.')
param privateEndpointSubnetResourceId string = ''

@description('Optional. Array of permitted IPs or IP CIDR blocks that can access the storage account using the Public Endpoint.')
param storagePermittedIPs array = []

@description('Optional. An array of subnet resource IDs where Service Endpoints will be created to allow access to the storage account through the public endpoint.')
param storageServiceEndpointSubnetResourceIds array = []

@description('Optional. The tags by resource type to apply to the resources created by this template.')
/*
tags = {
  'Microsoft.Compute/computeGalleries': {
    'Purpose': 'Image Management'
  },
  'Microsoft.Storage/storageAccounts': {
    'Purpose': 'Image Management'
  }
}
*/
param tags object = {}

@description('DO NOT MODIFY THIS VALUE! The timestamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param timeStamp string = utcNow('yyyyMMddhhmm')

// Naming conventions

var locations = loadJsonContent('../../.common/data/locations.json')[environment().name]
var resourceAbbreviations = loadJsonContent('../../.common/data/resourceAbbreviations.json')
var busUnitId = toLower(businessUnitIdentifier)
var nameConv_Suffix_withoutResType = !empty(envShortName) ? '${envShortName}-LOCATION' : 'LOCATION'
var nameConvSuffix = nameConvResTypeAtEnd ? '${nameConv_Suffix_withoutResType}-RESOURCETYPE' : nameConv_Suffix_withoutResType
var nameConv_Shared_ResGroups = nameConvResTypeAtEnd ? ( !empty(busUnitId) ? '${busUnitId}-RESGROUPPURPOSE-${nameConvSuffix}' : 'RESGROUPPURPOSE-${nameConvSuffix}' ) : ( !empty(busUnitId) ? 'RESOURCETYPE-${busUnitId}-RESGROUPPURPOSE-${nameConvSuffix}' : 'RESOURCETYPE-RESGROUPPURPOSE-${nameConvSuffix}' )
var nameConv_ImageManagement_ResGroup = centralizedImageManagement ? ( nameConvResTypeAtEnd ? 'RESGROUPPURPOSE-${nameConvSuffix}' : 'RESOURCETYPE-RESGROUPPURPOSE-${nameConvSuffix}' ) : nameConv_Shared_ResGroups
var nameConv_ImageManagement_Resources = centralizedImageManagement ? ( nameConvResTypeAtEnd ? 'image-management-${nameConvSuffix}' : 'RESOURCETYPE-image-management-${nameConvSuffix}' ) : ( nameConvResTypeAtEnd ? ( !empty(busUnitId) ? '${busUnitId}-image-management-${nameConvSuffix}' : 'image-management-${nameConvSuffix}' ) : ( !empty(busUnitId) ? 'RESOURCETYPE-${busUnitId}-image-management-${nameConvSuffix}' : 'RESOURCETYPE-image-managmeent-${nameConvSuffix}' ) )

var resourceGroupName = customResourceGroupName != 'none' ? customResourceGroupName : replace(replace(replace(nameConv_ImageManagement_ResGroup, 'RESGROUPPURPOSE', 'avd-image-management'), 'LOCATION', locations[location].abbreviation), 'RESOURCETYPE', resourceAbbreviations.resourceGroups)
var blobContainerName = replace(replace(toLower(artifactsContainerName), '_', '-'), ' ', '-')
var galleryName = customComputeGalleryName != 'none' ? customComputeGalleryName : replace(replace(nameConv_ImageManagement_Resources, 'RESOURCETYPE', resourceAbbreviations.computeGalleries), 'LOCATION', locations[location].abbreviation)
var computeGalleryName = replace(galleryName, '-', '_')
var identityName = customManagedIdentityName != 'none' ? customManagedIdentityName : replace(replace(nameConv_ImageManagement_Resources, 'RESOURCETYPE', resourceAbbreviations.userAssignedIdentities), 'LOCATION', locations[location].abbreviation)
var vnetName = !empty(privateEndpointSubnetResourceId) ? split(privateEndpointSubnetResourceId, '/')[8] : ''
var snetName = !empty(privateEndpointSubnetResourceId) ? split(privateEndpointSubnetResourceId, '/')[10] : ''
var privateEndpointNameConv = replace('${nameConvResTypeAtEnd ? 'RESOURCE-SUBRESOURCE-${vnetName}-${snetName}-RESOURCETYPE' : 'RESOURCETYPE-RESOURCE-SUBRESOURCE-${vnetName}-${snetName}'}', 'RESOURCETYPE', resourceAbbreviations.privateEndpoints)
var privateEndpointName = replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'blob'), 'RESOURCE', storageName)
var storageName = customArtifactsStorageAccountName != 'none' ? customArtifactsStorageAccountName : !empty(envShortName) ? take('${resourceAbbreviations.storageAccounts}imageassets${envShortName}${locations[location].abbreviation}${uniqueString(subscription().subscriptionId, resourceGroupName)}', 24) : take('${resourceAbbreviations.storageAccounts}imageassets${locations[location].abbreviation}${uniqueString(subscription().subscriptionId, resourceGroupName)}', 24)
var storageKind = 'StorageV2'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags.?resourceGroups ?? {}
}

module resources 'resources.bicep' = {
  scope: az.resourceGroup(resourceGroupName)
  name: 'Image-Management-Resources-${timeStamp}'
  params: {
    azureBlobPrivateDnsZoneResourceId: azureBlobPrivateDnsZoneResourceId
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceResourceId
    computeGalleryName: computeGalleryName
    storageAccountName: storageName
    blobContainerName: blobContainerName
    managedIdentityName: identityName
    privateEndpointName: privateEndpointName
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    storageAccessTier: storageAccessTier
    storageSASExpirationPeriod: storageSASExpirationPeriod
    storageKind: storageKind
    storageSkuName: storageSkuName
    storagePermittedIPs: storagePermittedIPs
    storageServiceEndpointSubnetResourceIds: storageServiceEndpointSubnetResourceIds
    storageAllowPublicNetworkAccess: storagePublicNetworkAccess
    storageAllowSharedKeyAccess: storageAllowSharedKeyAccess
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}

output storageAccountResourceId string    = resources.outputs.storageAccountResourceId
output blobContainerName string           = resources.outputs.blobContainerName
output managedIdentityClientId string     = resources.outputs.managedIdentityClientId
output managedIdentityResourceId string   = resources.outputs.managedIdentityResourceId
