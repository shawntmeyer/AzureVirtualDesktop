targetScope = 'subscription'

param activeDirectoryConnection bool
param identitySolution string
param availability string
param azureFilesPrivateDnsZoneResourceId string
param customerManagedKeysEnabled bool
param deploymentUserAssignedIdentityClientId string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param netAppVolumesSubnetResourceId string
param domainName string
param encryptionUserAssignedIdentityResourceId string
param fslogixFileShares array
param fslogixAdminGroups array
param fslogixUserGroups array
param shareSizeInGB int
param kerberosEncryptionType string
param storageEncryptionKeyVaultUris array
param location string
param logAnalyticsWorkspaceResourceId string
param managementVirtualMachineName string
param netAppAccountName string
param netAppCapacityPoolName string
param ouPath string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupManagement string
param resourceGroupStorage string
param smbServerLocation string
param storageAccountNamePrefix string
param storageCount int
param storageEncryptionKeyName string
param storageIndex int
param storageSku string
param storageSolution string
param tagsNetAppAccount object
param tagsPrivateEndpoints object
param tagsRecoveryServicesVault object
param tagsStorageAccounts object
param timeStamp string

module privateEndpointVnet '../common/VnetLocation.bicep' = if (privateEndpoint && !empty(privateEndpointSubnetResourceId)) {
  name: 'PrivateEndpointVnet_${timeStamp}'
  params: {
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
  }
}

// Azure NetApp files for fslogix
module azureNetAppFiles 'modules/azureNetAppFiles.bicep' = if (storageSolution == 'AzureNetAppFiles' && contains(identitySolution, 'DomainServices')) {
  name: 'AzureNetAppFiles_${timeStamp}'
  scope: resourceGroup(resourceGroupStorage)
  params: {
    activeDirectoryConnection: activeDirectoryConnection 
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainName: domainName
    shares: fslogixFileShares
    shareSizeInGB: shareSizeInGB
    shareAdminGroups: fslogixAdminGroups
    shareUserGroups: fslogixUserGroups
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    netAppAccountName: netAppAccountName
    netAppCapacityPoolName: netAppCapacityPoolName
    netAppVolumesSubnetResourceId: netAppVolumesSubnetResourceId
    ouPath: ouPath
    resourceGroupManagement: resourceGroupManagement
    smbServerLocation: smbServerLocation
    storageSku: storageSku
    storageSolution: storageSolution
    tagsNetAppAccount: tagsNetAppAccount
    timeStamp: timeStamp
  }
}

// Azure files for FSLogix
module azureFiles 'modules/azureFiles.bicep' = if (storageSolution == 'AzureFiles') {
  name: 'AzureFiles_${timeStamp}'
  scope: resourceGroup(resourceGroupStorage)
  params: {
    availability: availability
    azureFilesPrivateDnsZoneResourceId: azureFilesPrivateDnsZoneResourceId
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    customerManagedKeysEnabled: customerManagedKeysEnabled
    domainJoinUserPassword: contains(identitySolution, 'DomainServices') ? domainJoinUserPassword : ''
    domainJoinUserPrincipalName: contains(identitySolution, 'DomainServices') ? domainJoinUserPrincipalName : ''
    encryptionUserAssignedIdentityResourceId: encryptionUserAssignedIdentityResourceId
    fileShares: fslogixFileShares
    fslogixShareSizeInGB: shareSizeInGB
    fslogixAdminGroups: fslogixAdminGroups
    fslogixUserGroups: fslogixUserGroups
    identitySolution: identitySolution
    kerberosEncryptionType: kerberosEncryptionType
    encryptionKeyKeyVaultUris: storageEncryptionKeyVaultUris
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceResourceId
    managementVirtualMachineName: managementVirtualMachineName
    ouPath: ouPath
    privateEndpoint: privateEndpoint
    privateEndpointLocation: privateEndpoint && !empty(privateEndpointSubnetResourceId) ? privateEndpointVnet.outputs.location : ''
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    recoveryServices: recoveryServices
    recoveryServicesVaultName: recoveryServicesVaultName
    resourceGroupManagement: resourceGroupManagement
    resourceGroupStorage: resourceGroupStorage
    storageAccountNamePrefix: storageAccountNamePrefix
    storageCount: storageCount
    storageEncryptionKeyName: storageEncryptionKeyName
    storageIndex: storageIndex
    storageSku: storageSku
    storageSolution: storageSolution
    tagsPrivateEndpoints: tagsPrivateEndpoints
    tagsRecoveryServicesVault: tagsRecoveryServicesVault
    tagsStorageAccounts: tagsStorageAccounts
    timeStamp: timeStamp
  }
}

output netAppVolumeResourceIds array = storageSolution == 'AzureNetAppFiles' ? azureNetAppFiles.outputs.volumeResourceIds : []
output storageAccountResourceIds array = storageSolution == 'AzureFiles' ? azureFiles.outputs.storageAccountResourceIds : []
