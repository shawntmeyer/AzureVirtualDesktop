targetScope = 'subscription'

param activeDirectoryConnection string
param activeDirectorySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param automationAccountName string
param availability string
param azureFilesPrivateDnsZoneResourceId string
param azureFilesUserAssignedIdentityClientId string
param delegatedSubnetId string
param dnsServers string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param fileShares array
param fslogixShareSizeInGB int
param fslogixContainerType string
param fslogixStorageService string
param kerberosEncryption string
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
param storageIndex int
param storageSku string
param fslogixStorageSolution string
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
module azureNetAppFiles 'azureNetAppFiles.bicep' = if (fslogixStorageSolution == 'AzureNetAppFiles' && contains(activeDirectorySolution, 'DomainServices')) {
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
    fslogixContainerType: fslogixContainerType
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    netAppAccountName: netAppAccountName
    netAppCapacityPoolName: netAppCapacityPoolName
    ouPath: ouPath
    resourceGroupManagement: resourceGroupManagement
    securityPrincipalNames: securityPrincipalNames
    smbServerLocation: smbServerLocation
    storageSku: storageSku
    fslogixStorageSolution: fslogixStorageSolution
    tagsNetAppAccount: tagsNetAppAccount
    tagsVirtualMachines: tagsVirtualMachines
    timeStamp: timeStamp
  }
}

// Azure files for FSLogix
module azureFiles 'azureFiles/azureFiles.bicep' = if (fslogixStorageSolution == 'AzureFiles') {
  name: 'AzureFiles_${timeStamp}'
  scope: resourceGroup(resourceGroupStorage)
  params: {
    activeDirectorySolution: activeDirectorySolution
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    automationAccountName: automationAccountName
    availability: availability
    azureFilesPrivateDnsZoneResourceId: azureFilesPrivateDnsZoneResourceId
    azureFilesUserAssignedIdentityClientId: azureFilesUserAssignedIdentityClientId
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    fileShares: fileShares
    fslogixShareSizeInGB: fslogixShareSizeInGB
    fslogixContainerType: fslogixContainerType
    fslogixStorageService: fslogixStorageService
    kerberosEncryption: kerberosEncryption
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
    storageIndex: storageIndex
    storageSku: storageSku
    fslogixStorageSolution: fslogixStorageSolution
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

output netAppShares array = fslogixStorageSolution == 'AzureNetAppFiles' ? azureNetAppFiles.outputs.fileShares : [
  'None'
]
output storageAccountResourceIds array = fslogixStorageSolution == 'AzureFiles' ? azureFiles.outputs.storageAccountResourceIds : []
