param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param automationAccountName string
param availability string
param azureFilesPrivateDnsZoneResourceId string
param azureFilesUserAssignedIdentityClientId string
@secure()
param domainJoinUserPassword string
param domainJoinUserPrincipalName string
param activeDirectorySolution string
param fileShares array
param fslogixShareSizeInGB int
param fslogixContainerType string
param fslogixStorageService string
param kerberosEncryption string
param location string
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

var Endpoint = split(fslogixStorageService, ' ')[2]
var RoleDefinitionId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor  
var SmbMultiChannel = {
  multichannel: {
    enabled: true
  }
}
var SmbSettings = {
  versions: 'SMB3.0;SMB3.1.1;'
  authenticationMethods: 'NTLMv2;Kerberos;'
  kerberosTicketEncryption: kerberosEncryption == 'RC4' ? 'RC4-HMAC;' : 'AES-256;'
  channelEncryption: 'AES-128-CCM;AES-128-GCM;AES-256-GCM;'
}
var StorageRedundancy = availability == 'availabilityZones' ? '_ZRS' : '_LRS'
var privateEndpointSubnetId = resourceId(virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork, subnet)
var VirtualNetworkRules = {
  privateEndpoint: []
  PublicEndpoint: []
  ServiceEndpoint: [
    {
      id: privateEndpointSubnetId
      action: 'Allow'
    }
  ]
}

resource storageAccounts 'Microsoft.Storage/storageAccounts@2022-09-01' = [for i in range(0, storageCount): {
  name: '${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}'
  location: location
  tags: tagsStorageAccounts
  sku: {
    name: '${storageSku}${StorageRedundancy}'
  }
  kind: storageSku == 'Standard' ? 'StorageV2' : 'FileStorage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: VirtualNetworkRules[Endpoint]
      ipRules: []
      defaultAction: Endpoint == 'PublicEndpoint' ? 'Allow' : 'Deny'
    }
    publicNetworkAccess: Endpoint == 'privateEndpoint' ? 'Disabled' : 'Enabled'
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: activeDirectorySolution == 'AzureActiveDirectoryDomainServices' ? 'AADDS' : 'None'
    }
    largeFileSharesState: storageSku == 'Standard' ? 'Enabled' : null
  }
}]

// Assigns the SMB Contributor role to the Storage Account so users can save their profiles to the file share using FSLogix
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, storageCount): {
  scope: storageAccounts[i]
  name: guid(securityPrincipalObjectIds[i], RoleDefinitionId, storageAccounts[i].id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId)
    principalId: securityPrincipalObjectIds[i]
  }
}]

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = [for i in range(0, storageCount): {
  parent: storageAccounts[i]
  name: 'default'
  properties: {
    protocolSettings: {
      smb: storageSku == 'Standard' ? SmbSettings : union(SmbSettings, SmbMultiChannel)
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
    fslogixShareSizeInGB: fslogixShareSizeInGB
    StorageAccountName: storageAccounts[i].name
    storageSku: storageSku
  }
  dependsOn: [
    roleAssignment
  ]
}]

resource privateEndpoints 'Microsoft.Network/privateEndpoints@2020-05-01' = [for i in range(0, storageCount): if (privateEndpoint) {
  name: replace(replace(privateEndpointNameConv, 'subresource', 'file'), 'resource', '${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}')
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

resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-08-01' = [for i in range(0, storageCount): if (privateEndpoint || !empty(azureFilesPrivateDnsZoneResourceId)) {
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

module ntfsPermissions '../ntfsPermissions.bicep' = if (!contains(activeDirectorySolution, 'AzureActiveDirectory')) {
  name: 'FslogixNtfsPermissions_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    artifactsUri: artifactsUri
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    CommandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Set-NtfsPermissions.ps1 -ClientId ${azureFilesUserAssignedIdentityClientId} -domainJoinUserPassword "${domainJoinUserPassword}" -domainJoinUserPrincipalName ${domainJoinUserPrincipalName} -activeDirectorySolution ${activeDirectorySolution} -environmentShortName ${environment().name} -fslogixContainerType ${fslogixContainerType} -KerberosEncryptionType ${kerberosEncryption} -netbios ${netbios} -ouPath "${ouPath}" -securityPrincipalNames "${securityPrincipalNames}" -storageAccountPrefix ${storageAccountNamePrefix} -StorageAccountResourceGroupName ${resourceGroupStorage} -storageCount ${storageCount} -storageIndex ${storageIndex} -storageSolution ${storageSolution} -storageSuffix ${environment().suffixes.storage} -SubscriptionId ${subscription().subscriptionId} -TenantId ${subscription().tenantId}'
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    tagsVirtualMachines: tagsVirtualMachines
    timeStamp: timeStamp
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
    storageCount: storageCount
    storageIndex: storageIndex
    tagsRecoveryServicesVault: tagsRecoveryServicesVault
    timeStamp: timeStamp
  }
}

module autoIncreasePremiumFileShareQuota '../../management/autoIncreasePremiumFileShareQuota.bicep' = if (contains(fslogixStorageService, 'AzureFiles Premium') && storageCount > 0) {
  name: 'AutoIncreasePremiumFileShareQuota_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    artifactsUri: artifactsUri
    automationAccountName: automationAccountName
    fslogixContainerType: fslogixContainerType
    location: location
    storageAccountNamePrefix: storageAccountNamePrefix
    storageCount: storageCount
    storageIndex: storageIndex
    StorageResourceGroupName: resourceGroupStorage
    tags: tagsAutomationAccounts
    timeStamp: timeStamp
    timeZone: timeZone
  }
}
