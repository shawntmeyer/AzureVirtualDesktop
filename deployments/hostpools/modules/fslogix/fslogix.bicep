targetScope = 'subscription'

param activeDirectoryConnection bool
param identitySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param automationAccountName string
param availability string
param azureFilesPrivateDnsZoneResourceId string
param customerManagedKeysEnabled bool
param deploymentUserAssignedIdentityClientId string
param netAppVolumesSubnetResourceId string
param domainName string
param enableIncreaseQuotaAutomation bool
param encryptionUserAssignedIdentityResourceId string
param fileShares array
param shareSizeInGB int
param containerType string
param storageService string
param kerberosEncryption string
param vmKeyVaultName string
param storageEncryptionKeyVaultUris array
param location string
param logAnalyticsWorkspaceResourceId string
param managementVirtualMachineName string
param netAppAccountName string
param netAppCapacityPoolName string
param netbios string
param ouPath string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupManagement string
param resourceGroupStorage string
param securityPrincipalObjectIds array
param securityPrincipalNames array
param smbServerLocation string
param storageAccountNamePrefix string
param storageCount int
param storageEncryptionKeyName string
param storageIndex int
param storageSku string
param storageSolution string
param tagsAutomationAccounts object
param tagsNetAppAccount object
param tagsPrivateEndpoints object
param tagsRecoveryServicesVault object
param tagsStorageAccounts object
param timeStamp string
param timeZone string

resource vmKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (contains(identitySolution, 'DomainServices')) {
  name: vmKeyVaultName
  scope: resourceGroup(resourceGroupManagement)
}

// Azure NetApp files for fslogix
module azureNetAppFiles 'azureNetAppFiles.bicep' = if (storageSolution == 'AzureNetAppFiles' && contains(identitySolution, 'DomainServices')) {
  name: 'AzureNetAppFiles_${timeStamp}'
  scope: resourceGroup(resourceGroupStorage)
  params: {
    activeDirectoryConnection: activeDirectoryConnection
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId    
    domainJoinUserPassword: vmKeyVault.getSecret('domainJoinUserPassword')
    domainJoinUserPrincipalName: vmKeyVault.getSecret('domainJoinUserPrincipalName')
    domainName: domainName
    fileShares: fileShares
    fslogixContainerType: containerType
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    netAppAccountName: netAppAccountName
    netAppCapacityPoolName: netAppCapacityPoolName
    netAppVolumesSubnetResourceId: netAppVolumesSubnetResourceId
    ouPath: ouPath
    resourceGroupManagement: resourceGroupManagement
    securityPrincipalNames: securityPrincipalNames
    smbServerLocation: smbServerLocation
    storageSku: storageSku
    fslogixStorageSolution: storageSolution
    tagsNetAppAccount: tagsNetAppAccount
    timeStamp: timeStamp
  }
}

// Azure files for FSLogix
module azureFiles 'azureFiles/azureFiles.bicep' = if (storageSolution == 'AzureFiles') {
  name: 'AzureFiles_${timeStamp}'
  scope: resourceGroup(resourceGroupStorage)
  params: {
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    automationAccountName: automationAccountName
    availability: availability
    azureFilesPrivateDnsZoneResourceId: azureFilesPrivateDnsZoneResourceId
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    customerManagedKeysEnabled: customerManagedKeysEnabled
    domainJoinUserPassword: contains(identitySolution, 'DomainServices') ? vmKeyVault.getSecret('domainJoinUserPassword') : ''
    domainJoinUserPrincipalName: contains(identitySolution, 'DomainServices') ? vmKeyVault.getSecret('domainJoinUserPrincipalName') : ''
    enableIncreaseQuotaAutomation: enableIncreaseQuotaAutomation
    encryptionUserAssignedIdentityResourceId: encryptionUserAssignedIdentityResourceId
    fileShares: fileShares
    fslogixShareSizeInGB: shareSizeInGB
    fslogixContainerType: containerType
    fslogixStorageService: storageService
    identitySolution: identitySolution
    kerberosEncryption: kerberosEncryption
    encryptionKeyKeyVaultUris: storageEncryptionKeyVaultUris
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceResourceId
    managementVirtualMachineName: managementVirtualMachineName
    netbios: netbios
    ouPath: ouPath
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    recoveryServices: recoveryServices
    recoveryServicesVaultName: recoveryServicesVaultName
    resourceGroupManagement: resourceGroupManagement
    resourceGroupStorage: resourceGroupStorage
    securityPrincipalObjectIds: securityPrincipalObjectIds
    securityPrincipalNames: securityPrincipalNames
    storageAccountNamePrefix: storageAccountNamePrefix
    storageCount: storageCount
    storageEncryptionKeyName: storageEncryptionKeyName
    storageIndex: storageIndex
    storageSku: storageSku
    storageSolution: storageSolution
    tagsAutomationAccounts: tagsAutomationAccounts
    tagsPrivateEndpoints: tagsPrivateEndpoints
    tagsRecoveryServicesVault: tagsRecoveryServicesVault
    tagsStorageAccounts: tagsStorageAccounts
    timeStamp: timeStamp
    timeZone: timeZone
  }
}

output netAppShares array = storageSolution == 'AzureNetAppFiles' ? azureNetAppFiles.outputs.fileShares : []
output storageAccountResourceIds array = storageSolution == 'AzureFiles' ? azureFiles.outputs.storageAccountResourceIds : []
