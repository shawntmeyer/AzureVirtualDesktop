metadata name = 'Storage Account Blob Containers'
metadata description = 'This module deploys a Storage Account Blob Container.'
metadata owner = 'Azure/module-maintainers'

@maxLength(24)
@description('Conditional. The name of the parent Storage Account. Required if the template is used in a standalone deployment.')
param storageAccountName string

@description('Required. The name of the storage container to deploy.')
param name string

@description('Optional. Default the container to use specified encryption scope for all writes.')
param defaultEncryptionScope string = ''

@description('Optional. Block override of encryption scope from the container default.')
param denyEncryptionScopeOverride bool = false

@description('Optional. Enable NFSv3 all squash on blob container.')
param enableNfsV3AllSquash bool = false

@description('Optional. Enable NFSv3 root squash on blob container.')
param enableNfsV3RootSquash bool = false

@description('Optional. This is an immutable property, when set to true it enables object level immutability at the container level. The property is immutable and can only be set to true at the container creation time. Existing containers must undergo a migration process.')
param immutableStorageWithVersioningEnabled bool = false

@description('Optional. Name of the immutable policy.')
param immutabilityPolicyName string = 'default'

@description('Optional. Configure immutability policy.')
param immutabilityPolicyProperties object = {}

@description('Optional. A name-value pair to associate with the container as metadata.')
param metadata object = {}

@allowed([
  'Container'
  'Blob'
  'None'
])
@description('Optional. Specifies whether data in the container may be accessed publicly and the level of access.')
param publicAccess string = 'None'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName

  resource blobServices 'blobServices@2022-09-01' existing = {
    name: 'default'
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: name
  parent: storageAccount::blobServices
  properties: {
    defaultEncryptionScope: !empty(defaultEncryptionScope) ? defaultEncryptionScope : null
    denyEncryptionScopeOverride: denyEncryptionScopeOverride == true ? denyEncryptionScopeOverride : null
    enableNfsV3AllSquash: enableNfsV3AllSquash == true ? enableNfsV3AllSquash : null
    enableNfsV3RootSquash: enableNfsV3RootSquash == true ? enableNfsV3RootSquash : null
    immutableStorageWithVersioning: immutableStorageWithVersioningEnabled == true ? {
      enabled: immutableStorageWithVersioningEnabled
    } : null
    metadata: metadata
    publicAccess: publicAccess
  }
}

module immutabilityPolicy 'immutability-policy/main.bicep' = if (!empty(immutabilityPolicyProperties)) {
  name: immutabilityPolicyName
  params: {
    storageAccountName: storageAccount.name
    containerName: container.name
    immutabilityPeriodSinceCreationInDays: contains(immutabilityPolicyProperties, 'immutabilityPeriodSinceCreationInDays') ? immutabilityPolicyProperties.immutabilityPeriodSinceCreationInDays : 365
    allowProtectedAppendWrites: contains(immutabilityPolicyProperties, 'allowProtectedAppendWrites') ? immutabilityPolicyProperties.allowProtectedAppendWrites : true
    allowProtectedAppendWritesAll: contains(immutabilityPolicyProperties, 'allowProtectedAppendWritesAll') ? immutabilityPolicyProperties.allowProtectedAppendWritesAll : true
  }
}

@description('The name of the deployed container.')
output name string = container.name

@description('The resource ID of the deployed container.')
output resourceId string = container.id

@description('The resource group of the deployed container.')
output resourceGroupName string = resourceGroup().name
