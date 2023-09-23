param ArtifactsLocation string
param ArtifactsUserAssignedIdentityClientId string
param AutomationAccountName string
param Availability string
param AzureFilesPrivateDnsZoneResourceId string
param AzureFilesUserAssignedIdentityClientId string
@secure()
param DomainJoinPassword string
param DomainJoinUserPrincipalName string
param ActiveDirectorySolution string
param FileShares array
param FslogixShareSizeInGB int
param FslogixSolution string
param FslogixStorage string
param KerberosEncryption string
param Location string
param ManagementVmName string
param Netbios string
param OuPath string
param PrivateEndpoint bool
param RecoveryServices bool
param RecoveryServicesVaultName string
param ResourceGroupManagement string
param ResourceGroupStorage string
param SecurityPrincipalObjectIds array
param SecurityPrincipalNames array
param StorageAccountNamePrefix string
param StorageCount int
param StorageIndex int
param StorageSku string
param StorageSolution string
param Subnet string
param TagsAutomationAccounts object
param TagsPrivateEndpoints object
param TagsRecoveryServicesVault object
param TagsStorageAccounts object
param TagsVirtualMachines object
param Timestamp string
param TimeZone string
param VirtualNetwork string
param VirtualNetworkResourceGroup string

var Endpoint = split(FslogixStorage, ' ')[2]
var RoleDefinitionId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor  
var SmbMultiChannel = {
  multichannel: {
    enabled: true
  }
}
var SmbSettings = {
  versions: 'SMB3.0;SMB3.1.1;'
  authenticationMethods: 'NTLMv2;Kerberos;'
  kerberosTicketEncryption: KerberosEncryption == 'RC4' ? 'RC4-HMAC;' : 'AES-256;'
  channelEncryption: 'AES-128-CCM;AES-128-GCM;AES-256-GCM;'
}
var StorageRedundancy = Availability == 'AvailabilityZones' ? '_ZRS' : '_LRS'
var SubnetId = resourceId(VirtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', VirtualNetwork, Subnet)
var VirtualNetworkRules = {
  PrivateEndpoint: []
  PublicEndpoint: []
  ServiceEndpoint: [
    {
      id: SubnetId
      action: 'Allow'
    }
  ]
}

resource storageAccounts 'Microsoft.Storage/storageAccounts@2022-09-01' = [for i in range(0, StorageCount): {
  name: '${StorageAccountNamePrefix}${padLeft(i + StorageIndex, 2, '0')}'
  location: Location
  tags: TagsStorageAccounts
  sku: {
    name: '${StorageSku}${StorageRedundancy}'
  }
  kind: StorageSku == 'Standard' ? 'StorageV2' : 'FileStorage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: VirtualNetworkRules[Endpoint]
      ipRules: []
      defaultAction: Endpoint == 'PublicEndpoint' ? 'Allow' : 'Deny'
    }
    publicNetworkAccess: Endpoint == 'PrivateEndpoint' ? 'Disabled' : 'Enabled'
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
      directoryServiceOptions: ActiveDirectorySolution == 'AzureActiveDirectoryDomainServices' ? 'AADDS' : 'None'
    }
    largeFileSharesState: StorageSku == 'Standard' ? 'Enabled' : null
  }
}]

// Assigns the SMB Contributor role to the Storage Account so users can save their profiles to the file share using FSLogix
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, StorageCount): {
  scope: storageAccounts[i]
  name: guid(SecurityPrincipalObjectIds[i], RoleDefinitionId, storageAccounts[i].id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId)
    principalId: SecurityPrincipalObjectIds[i]
  }
}]

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = [for i in range(0, StorageCount): {
  parent: storageAccounts[i]
  name: 'default'
  properties: {
    protocolSettings: {
      smb: StorageSku == 'Standard' ? SmbSettings : union(SmbSettings, SmbMultiChannel)
    }
    shareDeleteRetentionPolicy: {
      enabled: false
    }
  }
}]

module shares 'shares.bicep' = [for i in range(0, StorageCount): {
  name: 'FileShares_${i}_${Timestamp}'
  params: {
    FileShares: FileShares
    FslogixShareSizeInGB: FslogixShareSizeInGB
    StorageAccountName: storageAccounts[i].name
    StorageSku: StorageSku
  }
  dependsOn: [
    roleAssignment
  ]
}]

resource privateEndpoints 'Microsoft.Network/privateEndpoints@2020-05-01' = [for i in range(0, StorageCount): if (PrivateEndpoint) {
  name: 'pe-${StorageAccountNamePrefix}${padLeft(i + StorageIndex, 2, '0')}'
  location: Location
  tags: TagsPrivateEndpoints
  properties: {
    subnet: {
      id: SubnetId
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

resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-08-01' = [for i in range(0, StorageCount): if (PrivateEndpoint) {
  parent: privateEndpoints[i]
  name: '${StorageAccountNamePrefix}${padLeft(i + StorageIndex, 2, '0')}'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'ipconfig1'
        properties: {
          privateDnsZoneId: AzureFilesPrivateDnsZoneResourceId
        }
      }
    ]
  }
  dependsOn: [
    storageAccounts
  ]
}]

module ntfsPermissions '../ntfsPermissions.bicep' = if (!contains(ActiveDirectorySolution, 'AzureActiveDirectory')) {
  name: 'FslogixNtfsPermissions_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    ArtifactsLocation: ArtifactsLocation
    UserAssignedIdentityClientId: ArtifactsUserAssignedIdentityClientId
    CommandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Set-NtfsPermissions.ps1 -ClientId ${AzureFilesUserAssignedIdentityClientId} -DomainJoinPassword "${DomainJoinPassword}" -DomainJoinUserPrincipalName ${DomainJoinUserPrincipalName} -ActiveDirectorySolution ${ActiveDirectorySolution} -Environment ${environment().name} -FslogixSolution ${FslogixSolution} -KerberosEncryptionType ${KerberosEncryption} -Netbios ${Netbios} -OuPath "${OuPath}" -SecurityPrincipalNames "${SecurityPrincipalNames}" -StorageAccountPrefix ${StorageAccountNamePrefix} -StorageAccountResourceGroupName ${ResourceGroupStorage} -StorageCount ${StorageCount} -StorageIndex ${StorageIndex} -StorageSolution ${StorageSolution} -StorageSuffix ${environment().suffixes.storage} -SubscriptionId ${subscription().subscriptionId} -TenantId ${subscription().tenantId}'
    Location: Location
    ManagementVmName: ManagementVmName
    TagsVirtualMachines: TagsVirtualMachines
    Timestamp: Timestamp
  }
  dependsOn: [
    privateDnsZoneGroups
    privateEndpoints
    shares
  ]
}

module recoveryServices 'recoveryServices.bicep' = if (RecoveryServices) {
  name: 'RecoveryServices_AzureFiles_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    FileShares: FileShares
    Location: Location
    RecoveryServicesVaultName: RecoveryServicesVaultName
    ResourceGroupStorage: ResourceGroupStorage
    StorageAccountNamePrefix: StorageAccountNamePrefix
    StorageCount: StorageCount
    StorageIndex: StorageIndex
    TagsRecoveryServicesVault: TagsRecoveryServicesVault
    Timestamp: Timestamp
  }
}

module autoIncreasePremiumFileShareQuota '../../management/autoIncreasePremiumFileShareQuota.bicep' = if (contains(FslogixStorage, 'AzureStorageAccount Premium') && StorageCount > 0) {
  name: 'AutoIncreasePremiumFileShareQuota_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    ArtifactsLocation: ArtifactsLocation
    AutomationAccountName: AutomationAccountName
    FslogixSolution: FslogixSolution
    Location: Location
    StorageAccountNamePrefix: StorageAccountNamePrefix
    StorageCount: StorageCount
    StorageIndex: StorageIndex
    StorageResourceGroupName: ResourceGroupStorage
    Tags: TagsAutomationAccounts
    Timestamp: Timestamp
    TimeZone: TimeZone
  }
}
