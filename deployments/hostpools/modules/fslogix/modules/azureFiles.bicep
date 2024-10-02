param availability string
param azureFilesPrivateDnsZoneResourceId string
param deploymentUserAssignedIdentityClientId string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param customerManagedKeysEnabled bool
param encryptionUserAssignedIdentityResourceId string
param fileShares array
param fslogixAdminGroups array
param fslogixShareSizeInGB int
param fslogixUserGroups array
param identitySolution string
param kerberosEncryptionType string
param encryptionKeyKeyVaultUris array
param location string
param logAnalyticsWorkspaceId string
param managementVirtualMachineName string
param ouPath string
param privateEndpoint bool
param privateEndpointLocation string
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupManagement string
param resourceGroupStorage string
param storageAccountNamePrefix string
param storageEncryptionKeyName string = ''
param storageCount int
param storageIndex int
param storageSku string
param storageSolution string
param tagsPrivateEndpoints object
param tagsRecoveryServicesVault object
param tagsStorageAccounts object
param timeStamp string

var adminRoleDefinitionId = 'a7264617-510b-434b-a828-9731dc254ea7' // Storage File Data SMB Share Elevated Contributor
var userRoleDefinitionId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor  
var fslogixShareUserGroupObjectIds = map(fslogixUserGroups, group => group.objectId)
var fslogixAdminGroupObjectIds = map(fslogixAdminGroups, group => group.objectId)

var privateEndpointVnetName = !empty(privateEndpointSubnetResourceId) && privateEndpoint ? split(privateEndpointSubnetResourceId, '/')[8] : ''

var smbMultiChannel = {
  multichannel: {
    enabled: true
  }
}
var smbSettings = {
  versions: 'SMB3.0;SMB3.1.1;'
  authenticationMethods: 'NTLMv2;Kerberos;'
  kerberosTicketEncryption: kerberosEncryptionType == 'RC4' ? 'RC4-HMAC;' : 'AES-256;'
  channelEncryption: 'AES-128-CCM;AES-128-GCM;AES-256-GCM;'
}
var storageRedundancy = availability == 'availabilityZones' ? '_ZRS' : '_LRS'

resource storageAccounts 'Microsoft.Storage/storageAccounts@2022-09-01' = [for i in range(0, storageCount): {
  name: '${storageAccountNamePrefix}${string(padLeft(i + storageIndex, 2, '0'))}'
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
        keyvaulturi: encryptionKeyKeyVaultUris[i]
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

module roleAssignmentsAdmins 'storageAccountRoleAssignment.bicep' = [for i in range(0, storageCount): if(contains(identitySolution, 'DomainServices') && !empty(fslogixAdminGroupObjectIds)){
  name: '${storageAccounts[i].name}_AdminRoleAssignments_${timeStamp}'
  params: {
    principalCount: length(fslogixAdminGroups)
    roleDefinitionId: adminRoleDefinitionId
    storageAccountName: storageAccounts[i].name
    objectIds: fslogixAdminGroupObjectIds
  }
}]

// Assigns the SMB Contributor role to the Storage Account so users can save their profiles to the file share using FSLogix.
module roleAssignmentsUsers 'storageAccountRoleAssignment.bicep' = if(storageCount == 1 && contains(identitySolution, 'DomainServices')) {
  name: 'StorageAccounts_UserRoleAssignments_${timeStamp}'
  params: {
    principalCount: length(fslogixUserGroups)
    roleDefinitionId: userRoleDefinitionId
    storageAccountName: storageAccounts[0].name
    objectIds: fslogixShareUserGroupObjectIds
  }
}

// Assigns the SMB Contributor role to the Storage Account so users can save their profiles to the file share using FSLogix. Since the storage count > 1, the count of security principals matches the number of storage accounts, so the role assignment is done in a loop 1:1.
module roleAssignmentsUsersSharding 'storageAccountRoleAssignment.bicep' = [for i in range(0, storageCount): if(!empty(fslogixUserGroups) && storageCount > 1 && contains(identitySolution, 'DomainServices')) {
  name: '${storageAccounts[i].name}_UserRoleAssignment_${timeStamp}'
  params: {
    principalCount: 1
    roleDefinitionId: userRoleDefinitionId
    storageAccountName: storageAccounts[i].name
    objectIds: array(fslogixShareUserGroupObjectIds[i])
  }
}]

module shares 'shares.bicep' = [for i in range(0, storageCount): {
  name: '${storageAccounts[i].name}_fileShares_${timeStamp}'
  params: {
    fileShares: fileShares
    shareSizeInGB: fslogixShareSizeInGB
    StorageAccountName: storageAccounts[i].name
    storageSku: storageSku
  }
  dependsOn: [
    roleAssignmentsUsers
    roleAssignmentsUsersSharding
    roleAssignmentsAdmins
  ]
}]

module privateEndpoints '../../../../sharedModules/resources/network/private-endpoint/main.bicep' = [for i in range(0, storageCount): if(privateEndpoint) {
  name: '${storageAccounts[i].name}_privateEndpoint_${timeStamp}'
  params: {
    customNetworkInterfaceName: replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'file'), 'RESOURCE', '${storageAccounts[i].name}'), 'VNETID', privateEndpointVnetName)
    groupIds: [
      'file'
    ]
    location: !empty(privateEndpointLocation) ? privateEndpointLocation : location
    name: replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'file'), 'RESOURCE', '${storageAccounts[i].name}'), 'VNETID', privateEndpointVnetName)
    privateDnsZoneGroup: {
      privateDNSResourceIds: [
        azureFilesPrivateDnsZoneResourceId
      ]
    }
    serviceResourceId: storageAccounts[i].id
    subnetResourceId: privateEndpointSubnetResourceId
    tags: tagsPrivateEndpoints
  }
}]

module SetNTFSPermissions 'domainJoinSetNTFSPermissions.bicep' = if(contains(identitySolution, 'DomainServices')) {
  name: 'Set-NTFSPermissions_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    adminGroupNames: map(fslogixAdminGroups, group => group.displayName)  
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainJoinUserPassword: domainJoinUserPassword
    kerberosEncryptionType: kerberosEncryptionType
    location: location  
    ouPath: ouPath
    resourceGroupStorage: resourceGroupStorage
    shares: fileShares
    storageAccountNamePrefix: storageAccountNamePrefix
    storageCount: storageCount
    storageIndex: storageIndex
    storageSolution: storageSolution
    timeStamp: timeStamp
    userAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
  dependsOn: [
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

resource storageAccounts_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for i in range(0, storageCount): if(!empty(logAnalyticsWorkspaceId)) {
  name: '${storageAccounts[i].name}-diagnosticSettings'
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
  name: '${storageAccounts[i].name}-file-diagnosticSettings'
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
