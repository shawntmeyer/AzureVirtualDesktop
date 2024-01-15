targetScope = 'subscription'

param Location string = deployment().location

@description('The subscription id where the storage account and associated resource should be deployed.')
param SubscriptionId string = subscription().subscriptionId

@maxLength(10)
@description('''Identifier used to describe the business unit (or customer) utilizing AVD in your tenant.
If not specified then centralized AVD Management is assumed and resources and resource groups are named accordingly.
If this is specified, then the "CentralizedAVDManagement" parameter determines how resources are organized and deployed.
''')
param BusinessUnitIdentifier string = ''

@description('''Conditional. When the "BusinessUnitIdentifier" parameter is not empty, this parameter determines if the AVD Management Resource Group and associated resources
are created in a centralized resource group (does not include "BusinessUnitIdentifier" in the name) and management resources are named accordingly or if a Business unit
specific AVD management resource group is created and management resources are named accordingly.
If the "BusinessUnitIdentifier" parameter is left empty ("") then this value has no effect.
''')
param CentralizedAVDManagement bool = false

@description('Reverse the normal Cloud Adoption Framework naming convention by putting the resource type abbreviation at the end of the resource name.')
param NameConvResTypeAtEnd bool = false

@description('Optional. The custom name of the Image Gallery to Deploy.')
param CustomComputeGalleryName string = ''

@description('Optional. Whether or not to deploy a Custom Image Gallery.')
param DeployComputeGallery bool = true

@minLength(3)
@maxLength(24)
@description('The name of the storage account to deploy. Must be at least 3 characters long. Should follow CAF naming conventions.')
param ArtifactsStorageAccountCustomName string = 'none'

@minLength(3)
@maxLength(63)
@description('Required. Blob Container Name. Must start with a letter. Can only contain lower case letters, numbers, and -.')
param BlobContainerName string

@description('Optional. Deploy Log Analytics Workspace for Monitoring the resources in this deployment.')
param DeployLogAnalytics bool = false

@description('Optional. Custom Name for the Log Analytics Workspace to create for monitoring this solution.')
param CustomLogAnalyticsWorkspaceName string = ''

@description('Optional. Resource Id of an existing Log Analytics Workspace to which diagnostic logs will be sent.')
param LogAnalyticsWorspaceResourceId string = ''

@minLength(3)
@maxLength(128)
@description('The name of the User Assigned Managed Identity that will be created and granted Storage Blob Data Reader Rights to the storage account for the Packer/Image Builder VMs.')
param ManagedIdentityName string = 'none'

@minLength(3)
@maxLength(63)
@description('The resource group name where the Storage Account will be created. It will be created if it does not exist.')
param ResourceGroupName string = 'none'

@allowed([
  'Dev'
  'Test'
  'Prod'
  ''
])
@description('The environment to which this storage account is being deployed.')
param Environment string = ''

@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
@description('Optional. Type of Storage Account to create.')
param StorageKind string = 'StorageV2'

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
param StorageSkuName string = 'Standard_LRS'

@allowed([
  'Premium'
  'Hot'
  'Cool'
])
@description('Conditional. Required if the Storage Account kind is set to BlobStorage. The access tier is used for billing. The "Premium" access tier is the default value for premium block blobs storage account type and it cannot be changed for the premium block blobs storage account type.')
param StorageAccessTier string = 'Hot'

@description('Optional. The Resource Id of the Private DNS Zone where the Private Endpoint (if configured) A record will be registered.')
param AzureBlobPrivateDnsZoneResourceId string = ''

@description('Required. Whether or not public network access is allowed for this resource. To limit public network access, use the "PermittedIPs" and/or the "ServiceEndpointSubnetResourceIds" parameters.')
@allowed([
  'Enabled'
  'Disabled'
])
param StoragePublicNetworkAccess string

@description('Optional. The ResourceId of the private endpoint subnet.')
param PrivateEndpointSubnetResourceId string = ''

@description('Optional. Array of permitted IPs or IP CIDR blocks that can access the storage account using the Public Endpoint.')
param StoragePermittedIPs array = []

@description('Optional. An array of subnet resource IDs where Service Endpoints will be created to allow access to the storage account through the public endpoint.')
param StorageServiceEndpointSubnetResourceIds array = []

@description('Optional. The tags to apply to the managed identity created by this template.')
param TagsManagedIdentities object = {}

@description('Optional. The tags to apply to the private endpoint created by this template.')
param TagsPrivateEndpoints object = {}

@description('Optional. The tags to apply to the storage account created by this template.')
param TagsStorageAccounts object = {}

@description('Optional. Indicates whether the storage account permits requests to be authorized with the account access key via Shared Key. If false, then all requests, including shared access signatures, must be authorized with Azure Active Directory (Azure AD). The default value is null, which is equivalent to true.')
param StorageAllowSharedKeyAccess bool = true

@description('Optional. The SAS expiration period. DD.HH:MM:SS.')
param StorageSASExpirationPeriod string = ''

@description('DO NOT MODIFY THIS VALUE! The timestamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param Timestamp string = utcNow('yyyyMMddhhmm')

var IPRules = [for IP in StoragePermittedIPs: {
  value: IP
  action: 'Allow'
}]

var VirtualNetworkRules = [for SubnetId in StorageServiceEndpointSubnetResourceIds: {
  id: SubnetId
  action: 'Allow'
}]

// Resource Names
module resourceNames '../../.common/bicep/namingConvention.bicep' = {
  name: 'ResourceNames_${Timestamp}'
  params: {
    Environment: Environment
    BusinessUnitIdentifier: BusinessUnitIdentifier
    CentralizedAVDManagement: CentralizedAVDManagement
    ComputeGalleryCustomName: CustomComputeGalleryName
    LocationManagement: Location
    NameConvResTypeAtEnd: NameConvResTypeAtEnd
    ArtifactsStorageAccountCustomName: ArtifactsStorageAccountCustomName
  }
}

module resourceGroup '../../.common/bicep/resources/resources/resource-group/main.bicep' = {
  name: 'ResourceGroup-${Timestamp}'
  params: {
    location: Location
    name: resourceNames.outputs.ResourceGroupImageManagement
    tags: TagsResourceGroups
  }
}

module imageManagementResources 'modules/resources.bicep' = {
  name: 'resources-${Timestamp}'
  params: {
    Location: Location
    
  }
}

module storageBlobReaderAssignment '../../.common/bicep/resources/authorization/role-assignment/resource-group/main.bicep' = {
  name: 'roleassign-blobreader-${Timestamp}'
  scope: az.resourceGroup(SubscriptionId, resourceNames.outputs.ResourceGroupImageManagement)
  params: {
    principalId: managedIdentity.outputs.principalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  }
}

output computeGalleryResourceId string    = computeGallery.outputs.resourceId
output storageAccountResourceId string    = storageAccount.outputs.resourceId
output blobContainerName string           = blobContainerName
output managedIdentityClientId string     = managedIdentity.outputs.clientId
output managedIdentityResourceId string   = managedIdentity.outputs.resourceId
