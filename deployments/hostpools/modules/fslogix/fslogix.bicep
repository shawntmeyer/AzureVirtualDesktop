targetScope = 'subscription'

param activeDirectoryConnection string
param identitySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param automationAccountName string
param availability string
param azureFilesPrivateDnsZoneResourceId string
param customerManagedKeysEnabled bool
param deploymentUserAssignedIdentityClientId string
param delegatedSubnetId string
param dnsServers string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param enableIncreaseQuotaAutomation bool
param encryptionUserAssignedIdentityResourceId string
param fileShares array
param shareSizeInGB int
param containerType string
param storageService string
param kerberosEncryption string
param keyVaultUri string
param location string
param managementVirtualMachineName string
param netAppAccountName string
param netAppCapacityPoolName string
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
param smbServerLocation string
param storageAccountNamePrefix string
param storageCount int
param storageEncryptionKeyName string
param storageIndex int
param storageSku string
param storageSolution string
param subnet string
param tagsAutomationAccounts object
param tagsNetAppAccount object
param tagsPrivateEndpoints object
param tagsRecoveryServicesVault object
param tagsStorageAccounts object
param tagsVirtualMachines object
param timeStamp string
param timeZone string
param virtualNetwork string
param virtualNetworkResourceGroup string

// Azure NetApp files for fslogix
module azureNetAppFiles 'azureNetAppFiles.bicep' = if (storageSolution == 'AzureNetAppFiles' && contains(identitySolution, 'DomainServices')) {
  name: 'AzureNetAppFiles_${timeStamp}'
  scope: resourceGroup(resourceGroupStorage)
  params: {
    activeDirectoryConnection: activeDirectoryConnection
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    delegatedSubnetId: delegatedSubnetId
    dnsServers: dnsServers
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainName: domainName
    fileShares: fileShares
    fslogixContainerType: containerType
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    netAppAccountName: netAppAccountName
    netAppCapacityPoolName: netAppCapacityPoolName
    ouPath: ouPath
    resourceGroupManagement: resourceGroupManagement
    securityPrincipalNames: securityPrincipalNames
    smbServerLocation: smbServerLocation
    storageSku: storageSku
    fslogixStorageSolution: storageSolution
    tagsNetAppAccount: tagsNetAppAccount
    tagsVirtualMachines: tagsVirtualMachines
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
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    enableIncreaseQuotaAutomation: enableIncreaseQuotaAutomation
    encryptionUserAssignedIdentityResourceId: encryptionUserAssignedIdentityResourceId
    fileShares: fileShares
    fslogixShareSizeInGB: shareSizeInGB
    fslogixContainerType: containerType
    fslogixStorageService: storageService
    identitySolution: identitySolution
    kerberosEncryption: kerberosEncryption
    keyVaultUri: keyVaultUri
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    netbios: netbios
    ouPath: ouPath
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
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
    subnet: subnet
    tagsAutomationAccounts: tagsAutomationAccounts
    tagsPrivateEndpoints: tagsPrivateEndpoints
    tagsRecoveryServicesVault: tagsRecoveryServicesVault
    tagsStorageAccounts: tagsStorageAccounts
    tagsVirtualMachines: tagsVirtualMachines
    timeStamp: timeStamp
    timeZone: timeZone
    virtualNetwork: virtualNetwork
    virtualNetworkResourceGroup: virtualNetworkResourceGroup
  }
}

output netAppShares array = storageSolution == 'AzureNetAppFiles' ? azureNetAppFiles.outputs.fileShares : []
output storageAccountResourceIds array = storageSolution == 'AzureFiles' ? azureFiles.outputs.storageAccountResourceIds : []
