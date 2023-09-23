@description('Optional. The Resource Id of the Private DNS Zone where the Private Endpoint (if configured) A record will be registered.')
param AzureBlobPrivateDnsZoneResourceId string = ''

param Location string = resourceGroup().location

@description('Optional. Determines whether to create a Private Endpoint for the storage account. Requires that the PrivateEndpointSubnetResourceId parameter be completed.')
param CreatePrivateEndpoint bool = false

@maxLength(24)
@description('Required. Name of the Storage Account.')
param StorageAccountName string

@minLength(3)
@maxLength(63)
@description('Required. Blob Container Name')
param BlobContainerName string

@minLength(3)
@maxLength(128)
param ManagedIdentityName string

@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
@description('Required. Type of Storage Account to create.')
param Kind string

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
@description('Required. Storage Account Sku Name.')
param SkuName string

@allowed([
  'Premium'
  'Hot'
  'Cool'
])
@description('Conditional. Required if the Storage Account kind is set to BlobStorage. The access tier is used for billing. The "Premium" access tier is the default value for premium block blobs storage account type and it cannot be changed for the premium block blobs storage account type.')
param AccessTier string = 'Hot'

@description('Optional. The ResourceId of the subnet where the Private Endpoint will be created.')
param PrivateEndpointSubnetResourceId string = ''

@description('Optional. The tags to apply to the managed identity created by this template.')
param TagsManagedIdentities object = {}

@description('Optional. The tags to apply to the private endpoint created by this template.')
param TagsPrivateEndpoints object = {}

@description('Optional. The tags to apply to the storage account created by this template.')
param TagsStorageAccounts object = {}

@description('Required. Indicates whether the storage account permits requests to be authorized with the account access key via Shared Key. If false, then all requests, including shared access signatures, must be authorized with Azure Active Directory (Azure AD). The default value is null, which is equivalent to true.')
param AllowSharedKeyAccess bool

@description('''Required. Whether or not public network access is allowed for this resource.
For security reasons it should be disabled; therefore, if you do not specify "PermittedIPs" or "ServiceEndpointSubnetResourceIds" and you set "CreatePrivateEndpoint" to true,
then Public Network Access is automatically disabled.''')
@allowed([
  'Enabled'
  'Disabled'
])
param PublicNetworkAccess string

@description('Optional. List of IPs and IP prefixes that are to be allowed through the Storage Account Firewall.')
param PermittedIPs array = []

@description('Optional. Array of subnet resource Ids where service endpoints are created for the storage account and permitted through the Storage Account Firewall.')
param ServiceEndpointSubnetResourceIds array = []

@description('Optional. The SAS expiration period. DD.HH:MM:SS.')
param SASExpirationPeriod string = ''

var IPRules = [for IP in PermittedIPs: {
  value: IP
  action: 'Allow'
}]

var VirtualNetworkRules = [for SubnetId in ServiceEndpointSubnetResourceIds: {
  id: SubnetId
  action: 'Allow'
}]

var PrivateEndpoint = empty(PrivateEndpointSubnetResourceId) ? false : CreatePrivateEndpoint

var RoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: StorageAccountName
  location: Location
  tags: TagsStorageAccounts
  sku: {
    name: SkuName
  }
  kind: Kind
  properties: {
    accessTier: AccessTier
    allowBlobPublicAccess: false
    allowSharedKeyAccess: AllowSharedKeyAccess
    minimumTlsVersion: 'TLS1_2'
    networkAcls: !(empty(IPRules)) || !(empty(ServiceEndpointSubnetResourceIds)) ? {
      bypass: 'AzureServices'
      virtualNetworkRules: VirtualNetworkRules
      ipRules: IPRules
      defaultAction: 'Deny'
    } : null
    publicNetworkAccess: PublicNetworkAccess
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
      }
      requireInfrastructureEncryption: true
      keySource: 'Microsoft.Storage'
    }
    sasPolicy: !empty(SASExpirationPeriod) ? {
      expirationAction: 'Log'
      sasExpirationPeriod: SASExpirationPeriod
    } : null
    
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    changeFeed: {
      enabled: true
      retentionInDays: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
      allowPermanentDelete: true
    }
    defaultServiceVersion: null
    deleteRetentionPolicy: {
      enabled: true
      days: 7
      allowPermanentDelete: true
    }
    isVersioningEnabled: true
    lastAccessTimeTrackingPolicy: {
      enable: true
      name: 'AccessTimeTracking'
      trackingGranularityInDays: 1
    }
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: BlobContainerName
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-05-01' = if (PrivateEndpoint) {
  name: 'pe-${storageAccount.name}-blob'
  location: Location
  tags: TagsPrivateEndpoints
  properties: {
    subnet: {
      id: PrivateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${storageAccount.name}_${guid(storageAccount.name)}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-08-01' = if (PrivateEndpoint && !empty(AzureBlobPrivateDnsZoneResourceId)) {
  parent: privateEndpoint
  name: storageAccount.name
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'ipconfig1'
        properties: {
          privateDnsZoneId: AzureBlobPrivateDnsZoneResourceId
        }
      }
    ]
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: ManagedIdentityName
  location: Location
  tags: TagsManagedIdentities
}

resource storageBlobReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ManagedIdentityName, storageAccount.name, RoleDefinitionId)
  scope: storageAccount
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: RoleDefinitionId
  }
}

output storageAccountResourceId string    = storageAccount.id
output blobContainerName string           = blobContainer.name
output managedIdentityClientId string     = managedIdentity.properties.clientId
output managedIdentityResourceId string   = managedIdentity.id

