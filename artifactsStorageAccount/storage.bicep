targetScope = 'subscription'

@description('The subscription id where the storage account and associated resource should be deployed.')
param SubscriptionId string = subscription().subscriptionId

@minLength(3)
@maxLength(24)
@description('The name of the storage account to deploy. Must be at least 3 characters long. Should follow CAF naming conventions.')
param StorageAccountName string = 'none'

@minLength(3)
@maxLength(11)
@description('Supply this value to automatically generate a deterministic and unique storage account name during deployment.')
param StorageAccountNamePrefix string = 'none'

@minLength(3)
@maxLength(63)
@description('Required. Blob Container Name. Must start with a letter. Can only contain lower case letters, numbers, and -.')
param BlobContainerName string

@minLength(3)
@maxLength(128)
@description('The name of the User Assigned Managed Identity that will be created and granted Storage Blob Data Reader Rights to the storage account for the Packer/Image Builder VMs.')
param ManagedIdentityName string = 'none'

@minLength(3)
@maxLength(63)
@description('The resource group name where the Storage Account will be created. It will be created if it does not exist.')
param ResourceGroupName string = 'none'

@description('The location to deploy the resources in this template.')
param Location string = deployment().location

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
param Kind string = 'StorageV2'

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
param SkuName string = 'Standard_LRS'

@allowed([
  'Premium'
  'Hot'
  'Cool'
])
@description('Conditional. Required if the Storage Account kind is set to BlobStorage. The access tier is used for billing. The "Premium" access tier is the default value for premium block blobs storage account type and it cannot be changed for the premium block blobs storage account type.')
param AccessTier string = 'Hot'

@description('Optional. The Resource Id of the Private DNS Zone where the Private Endpoint (if configured) A record will be registered.')
param AzureBlobPrivateDnsZoneResourceId string = ''

@description('Required. Whether or not public network access is allowed for this resource. To limit public network access, use the "PermittedIPs" and/or the "ServiceEndpointSubnetResourceIds" parameters.')
@allowed([
  'Enabled'
  'Disabled'
])
param PublicNetworkAccess string

@description('Optional. Create a private endpoint on the subnet specified in the "PrivateEndpointSubnetResourceID" parameter.')
param CreatePrivateEndpoint bool = false

@description('Optional. The ResourceId of the private endpoint subnet.')
param PrivateEndpointSubnetResourceId string = ''

@description('Optional. Array of permitted IPs or IP CIDR blocks that can access the storage account using the Public Endpoint.')
param PermittedIPs array = []

@description('Optional. An array of subnet resource IDs where Service Endpoints will be created to allow access to the storage account through the public endpoint.')
param ServiceEndpointSubnetResourceIds array = []

@description('Optional. The tags to apply to the managed identity created by this template.')
param TagsManagedIdentities object = {}

@description('Optional. The tags to apply to the private endpoint created by this template.')
param TagsPrivateEndpoints object = {}

@description('Optional. The tags to apply to the storage account created by this template.')
param TagsStorageAccounts object = {}

@description('Optional. Indicates whether the storage account permits requests to be authorized with the account access key via Shared Key. If false, then all requests, including shared access signatures, must be authorized with Azure Active Directory (Azure AD). The default value is null, which is equivalent to true.')
param AllowSharedKeyAccess bool = true

@description('Optional. The SAS expiration period. DD.HH:MM:SS.')
param SASExpirationPeriod string = ''

@description('DO NOT MODIFY THIS VALUE! The timestamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param Timestamp string = utcNow('yyyyMMddhhmmss')

var locations = loadJsonContent('../data/locations.json')
var ResourceAbbreviations = loadJsonContent('../data/resourceAbbreviations.json')

var resGroupName = ResourceGroupName != 'none' ? ResourceGroupName : !empty(Environment) ? '${ResourceAbbreviations.resourceGroups}-image-management-${Environment}-${locations[Location].abbreviation}' : '${ResourceAbbreviations.resourceGroups}-image-management-${locations[Location].abbreviation}'
var storageName = StorageAccountName != 'none' ? StorageAccountName : StorageAccountNamePrefix != 'none' ? '${StorageAccountNamePrefix}${guid(StorageAccountNamePrefix, resGroupName, SubscriptionId)}' : !empty(Environment) ? '${ResourceAbbreviations.storageAccounts}imageassets${Environment}${locations[Location].abbreviation}' : '${ResourceAbbreviations.storageAccounts}imageassets${locations[Location].abbreviation}'
var identityName = ManagedIdentityName != 'none' ? ManagedIdentityName : !empty(Environment) ? '${ResourceAbbreviations.userAssignedIdentities}-image-management-${Environment}-${locations[Location].abbreviation}' : '${ResourceAbbreviations.userAssignedIdentities}-image-management-${locations[Location].abbreviation}'
var blobContainerName = replace(replace(toLower(BlobContainerName), '_', '-'), ' ', '-')

module resourceGroup 'modules/resourceGroup.bicep' = {
  scope: subscription(SubscriptionId)
  name: 'RG-StorageResourceGroup-${Timestamp}'
  params: {
    ResourceGroupName: resGroupName
    Location: Location
  }
}

module resources 'modules/resources.bicep' = {
  scope: az.resourceGroup(SubscriptionId,resGroupName)
  name: 'Storage-Account-Resources-${Timestamp}'
  params: {
    AccessTier: AccessTier
    AllowSharedKeyAccess: AllowSharedKeyAccess
    AzureBlobPrivateDnsZoneResourceId: AzureBlobPrivateDnsZoneResourceId
    BlobContainerName: blobContainerName
    CreatePrivateEndpoint: CreatePrivateEndpoint
    PermittedIPs: PermittedIPs
    Location: Location
    ManagedIdentityName: identityName
    PublicNetworkAccess: PublicNetworkAccess
    ServiceEndpointSubnetResourceIds: ServiceEndpointSubnetResourceIds
    StorageAccountName: storageName
    PrivateEndpointSubnetResourceId: PrivateEndpointSubnetResourceId
    TagsManagedIdentities: TagsManagedIdentities
    TagsPrivateEndpoints: TagsPrivateEndpoints
    TagsStorageAccounts: TagsStorageAccounts
    SASExpirationPeriod: SASExpirationPeriod
    SkuName: SkuName
    Kind: Kind
  }
  dependsOn: [
    resourceGroup
  ]
}

output storageAccountResourceId string    = resources.outputs.storageAccountResourceId
output blobContainerName string           = resources.outputs.blobContainerName
output managedIdentityClientId string     = resources.outputs.managedIdentityClientId
output managedIdentityResourceId string   = resources.outputs.managedIdentityResourceId
