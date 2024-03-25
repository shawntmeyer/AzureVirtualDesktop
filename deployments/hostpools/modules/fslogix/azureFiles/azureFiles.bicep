param identitySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param automationAccountName string
param availability string
param azureFilesPrivateDnsZoneResourceId string
param deploymentUserAssignedIdentityClientId string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param customerManagedKeysEnabled bool
param enableIncreaseQuotaAutomation bool
param encryptionUserAssignedIdentityResourceId string
param fileShares array
param fslogixShareSizeInGB int
param fslogixContainerType string
param fslogixStorageService string
param kerberosEncryption string
param keyVaultUri string
param location string
param logAnalyticsWorkspaceId string
param managementVirtualMachineName string
param netbios string
param ouPath string
param privateEndpoint bool
param privateEndpointNameConv string
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupManagement string
param resourceGroupStorage string
param securityPrincipalObjectIds array
param securityPrincipalNames array
@minLength(1)
param storageAccountNamePrefix string
param storageEncryptionKeyName string = ''
param storageCount int
param storageIndex int
param storageSku string
param storageSolution string
param subnet string
param tagsAutomationAccounts object
param tagsPrivateEndpoints object
param tagsRecoveryServicesVault object
param tagsStorageAccounts object
param tagsVirtualMachines object
param timeStamp string
param timeZone string
param virtualNetwork string
param virtualNetworkResourceGroup string

var roleDefinitionId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor  
var smbMultiChannel = {
  multichannel: {
    enabled: true
  }
}
var smbSettings = {
  versions: 'SMB3.0;SMB3.1.1;'
  authenticationMethods: 'NTLMv2;Kerberos;'
  kerberosTicketEncryption: kerberosEncryption == 'RC4' ? 'RC4-HMAC;' : 'AES-256;'
  channelEncryption: 'AES-128-CCM;AES-128-GCM;AES-256-GCM;'
}
var storageRedundancy = availability == 'availabilityZones' ? '_ZRS' : '_LRS'
var privateEndpointSubnetId = resourceId(virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork, subnet)

resource storageAccounts 'Microsoft.Storage/storageAccounts@2022-09-01' = [for i in range(0, storageCount): {
  name: '${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}'
  kind: storageSku == 'Standard' ? 'StorageV2' : 'FileStorage'
  location: location
  identity: customerManagedKeysEnabled ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${encryptionUserAssignedIdentityResourceId}': {}
    }
  } : null
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowedCopyScope: 'AAD'
    allowSharedKeyAccess: true
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: identitySolution == 'EntraDomainServices' ? 'AADDS' : 'None'
    }
    defaultToOAuthAuthentication: false
    dnsEndpointType: 'Standard'
    encryption: {
      identity: customerManagedKeysEnabled ? {
        userAssignedIdentity: encryptionUserAssignedIdentityResourceId
      } : null
      services: storageSku == 'Standard' ? {
        blob: {
          keyType: 'Account'
          enabled: true
        }
        file: {
          keyType: 'Account'
          enabled: true
        }
      } : {
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: customerManagedKeysEnabled ? 'Microsoft.KeyVault' : 'Microsoft.Storage'
      keyvaultproperties: customerManagedKeysEnabled ? {
        keyname: storageEncryptionKeyName
        keyvaulturi: keyVaultUri
      } : null
      requireInfrastructureEncryption: true
    }
    largeFileSharesState: storageSku == 'Standard' ? 'Enabled' : null
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: privateEndpoint ? 'Deny' : 'Allow'
    }
    publicNetworkAccess: privateEndpoint ? 'Disabled' : 'Enabled'
    sasPolicy: {
      expirationAction: 'Log'
      sasExpirationPeriod: '180.00:00:00'
    }
    supportsHttpsTrafficOnly: true
  }
  sku: {
    name: '${storageSku}${storageRedundancy}'
  }
  tags: tagsStorageAccounts
}]

// Assigns the SMB Contributor role to the Storage Account so users can save their profiles to the file share using FSLogix
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, storageCount): if(!contains(identitySolution,'EntraId')) {
  scope: storageAccounts[i]
  name: guid(securityPrincipalObjectIds[i], roleDefinitionId, storageAccounts[i].id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: securityPrincipalObjectIds[i]
  }
}]

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = [for i in range(0, storageCount): {
  parent: storageAccounts[i]
  name: 'default'
  properties: {
    protocolSettings: {
      smb: storageSku == 'Standard' ? smbSettings : union(smbSettings, smbMultiChannel)
    }
    shareDeleteRetentionPolicy: {
      enabled: false
    }
  }
}]

module shares 'shares.bicep' = [for i in range(0, storageCount): {
  name: 'FileShares_${i}_${timeStamp}'
  params: {
    fileShares: fileShares
    shareSizeInGB: fslogixShareSizeInGB
    StorageAccountName: storageAccounts[i].name
    storageSku: storageSku
  }
  dependsOn: [
    roleAssignment
  ]
}]

resource privateEndpoints 'Microsoft.Network/privateEndpoints@2020-05-01' = [for i in range(0, storageCount): if (privateEndpoint) {
  name: replace(replace(replace(privateEndpointNameConv, 'subresource', 'file'), 'resource', '${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}'), '-uniqueString', '.${uniqueString(privateEndpointSubnetId)}')
  location: location
  tags: tagsPrivateEndpoints
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${storageAccounts[i].name}_${guid(storageAccounts[i].name)}'
        properties: {
          privateLinkServiceId: storageAccounts[i].id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}]

resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-08-01' = [for i in range(0, storageCount): if (privateEndpoint && !empty(azureFilesPrivateDnsZoneResourceId)) {
  parent: privateEndpoints[i]
  name: '${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'ipconfig1'
        properties: {
          privateDnsZoneId: azureFilesPrivateDnsZoneResourceId
        }
      }
    ]
  }
  dependsOn: [
    storageAccounts
  ]
}]

module ntfsPermissions '../../common/customScriptExtensions.bicep' = if (!contains(identitySolution, 'EntraId')) {
  name: 'FslogixNtfsPermissions_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    location: location
    fileUris: ['${artifactsUri}Set-NtfsPermissions.ps1']
    parameters: '-ClientId ${deploymentUserAssignedIdentityClientId} -DomainJoinUserPassword "${domainJoinUserPassword}" -DomainJoinUserPrincipalName ${domainJoinUserPrincipalName} -ActiveDirectorySolution ${identitySolution} -Environment ${environment().name} -FslogixContainerType ${fslogixContainerType} -KerberosEncryptionType ${kerberosEncryption} -Netbios ${netbios} -OUPath "${ouPath}" -SecurityPrincipalNames "${securityPrincipalNames}" -StorageAccountPrefix ${storageAccountNamePrefix} -StorageAccountResourceGroupName ${resourceGroupStorage} -StorageCount ${storageCount} -StorageIndex ${storageIndex} -StorageSolution ${storageSolution} -StorageSuffix ${environment().suffixes.storage} -SubscriptionId ${subscription().subscriptionId} -TenantId ${subscription().tenantId}'
    scriptFileName: 'Set-NtfsPermissions.ps1'
    tags: tagsVirtualMachines
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
  dependsOn: [
    privateDnsZoneGroups
    privateEndpoints
    shares
  ]
}

module recServices 'recoveryServices.bicep' = if (recoveryServices) {
  name: 'RecoveryServices_AzureFiles_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    fileShares: fileShares
    location: location
    recoveryServicesVaultName: recoveryServicesVaultName
    resourceGroupStorage: resourceGroupStorage
    storageAccountNamePrefix: storageAccountNamePrefix
    fslogixStorageCount: storageCount
    fslogixStorageIndex: storageIndex
    tagsRecoveryServicesVault: tagsRecoveryServicesVault
    timeStamp: timeStamp
  }
}

module autoIncreasePremiumFileShareQuota '../../management/autoIncreasePremiumFileShareQuota.bicep' = if (enableIncreaseQuotaAutomation && contains(fslogixStorageService, 'AzureFiles Premium') && storageCount > 0) {
  name: 'AutoIncreasePremiumFileShareQuota_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    artifactsUri: artifactsUri
    automationAccountName: automationAccountName
    fslogixContainerType: fslogixContainerType
    location: location
    storageAccountNamePrefix: storageAccountNamePrefix
    fslogixStorageCount: storageCount
    fslogixStorageIndex: storageIndex
    storageResourceGroupName: resourceGroupStorage
    tags: tagsAutomationAccounts
    timeStamp: timeStamp
    timeZone: timeZone
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    managementVirtualMachineName: managementVirtualMachineName
  }
}

resource storageAccounts_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for i in range(0, storageCount): if(!empty(logAnalyticsWorkspaceId)) {
  name: '${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}-diagnosticSettings'
  properties: {
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspaceId
  }
  scope: storageAccounts[i]
}]

resource storageAccounts_file_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for i in range(0, storageCount): if(!empty(logAnalyticsWorkspaceId)) {
  name: '${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}-file-diagnosticSettings'
  scope: fileServices[i]
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}]

output storageAccountResourceIds array = [for i in range(0, storageCount): storageAccounts[i].id]
