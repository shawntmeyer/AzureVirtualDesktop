param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param confidentialVMOSDiskEncryption bool
param confidentialVMOrchestratorObjectId string
param deploymentUserAssignedIdentityClientId string
param diskEncryptionSetNames object
param diskEncryptionSetEncryptionType string
param envShortName string
param keyManagementFSLogixStorage string
param keyManagementDisks string
param vmKeyVaultName string
param storageIndex int
param storageKeyVaultNameConv string
param keyVaultPrivateDnsZoneResourceId string
param location string
param managementVirtualMachineName string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param storageCount int
param tags object
param timeStamp string
param userAssignedIdentityNameConv string

var cseScriptParameters = confidentialVMOSDiskEncryption ? '-keyVaultName ${vmKeyVaultName} -keyName ConfidentialVMOSDiskEncryptionKey -Environment ${environment().name} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${deploymentUserAssignedIdentityClientId}' : ''

var storageAccountEncryptionKeyName = 'StorageAccountEncryptionKey'

resource vmKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: vmKeyVaultName
}

module encryption_key_disks 'keyVaultKeys.bicep' = if (!confidentialVMOSDiskEncryption) {
  name: 'EncryptionKey_VMDiskEncryption_${timeStamp}'
  params: {
    exportable: false
    keyName: 'VMOSDiskEncryptionKey'
    keyType: contains(keyManagementDisks, 'HSM') ? 'RSA-HSM' : 'RSA'
    keyVaultName: vmKeyVaultName
    rotationPolicy: true
  }
}

module confidentialVM_key_disks '../../../sharedModules/custom/customScriptExtension.bicep' = if(confidentialVMOSDiskEncryption) {
  name: 'EncryptionKey_ConfidentialVMOSDisk_${timeStamp}'
  params: {
    commandToExecute: 'powershell.exe -executionpolicy Bypass -File Create-ConfidentialVMOSDiskEncryptionKey.ps1 ${cseScriptParameters}'
    fileUris: [
      '${artifactsUri}Create-ConfidentialVMOSDiskEncryptionKey.ps1'
    ]
    location: location
    output: true
    tags: contains(tags, 'Microsoft.Compute/virtualMachines/extensions') ? tags['Microsoft.Compute/virtualMachines/extensions'] : {}
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
}

module storageAccountKeyVaults 'keyVault.bicep' = [for i in range(0, storageCount): {
  name: 'Storage_KeyVault_${i + storageIndex}_${timeStamp}'
  params: {
    envShortName: envShortName
    keyVaultName: replace(storageKeyVaultNameConv, 'INDEX', string(i + storageIndex))
    enabledForDiskEncryption: false
    enablePurgeProtection: true
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    location: location
    skuName: contains(keyManagementFSLogixStorage, 'HSM') ? 'premium' : 'standard'
    tagsKeyVault: contains(tags, 'Microsoft.KeyVault/vaults') ? tags['Microsoft.KeyVault/vaults'] : {}
    tagsPrivateEndpoints: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
    timeStamp: timeStamp
  }
}]

module keysStorageAccounts 'keyVaultKeys.bicep' = [for i in range(0, storageCount): {
  name: 'EncryptionKey_StorageAccount_${string(i + storageIndex)}_${timeStamp}'
  params: {
    exportable: false
    keyName: storageAccountEncryptionKeyName
    keyType: contains(keyManagementFSLogixStorage, 'HSM') ? 'RSA-HSM' : 'RSA'
    keyVaultName: last(split(storageAccountKeyVaults[i].outputs.keyVaultResourceId, '/')) 
    rotationPolicy: true
  }
}]

module userAssignedIdentity 'userAssignedIdentity.bicep' = {
  name: 'UAI_Encryption_${timeStamp}'
  params: {
    location: location
    name: replace(userAssignedIdentityNameConv, 'UAIPURPOSE', 'encryption')
    tags: contains(tags, 'Microsoft.ManagedIdentity/userAssignedIdentities') ? tags['Microsoft.ManagedIdentity/userAssignedIdentities'] : {}
  }
}

module roleAssignment_UAI_EncryptUser '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = {
  name: 'RoleAssignment_Encryption_UAI_EncryptUser_${timeStamp}'
  params: {
    principalId: userAssignedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

module roleAssignment_ConfVMOrchestrator_EncryptUser '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = if (confidentialVMOSDiskEncryption) {
  name: 'RoleAssignment_ConfVMOrchestrator_EncryptUser_${timeStamp}'
  params: {
    principalId: confidentialVMOrchestratorObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

module roleAssignment_ConfVMOrchestrator_ReleaseUser '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = if (confidentialVMOSDiskEncryption) {
  name: 'RoleAssignment_ConfVMOrchestrator_ReleaseUser_${timeStamp}'
  params: {
    principalId: confidentialVMOrchestratorObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '08bbd89e-9f13-488c-ac41-acfcb10c90ab' // Key Vault Crypto Service Release User
  }
}

module diskEncryptionSet 'diskEncryptionSet.bicep' = {
  name: 'DiskEncryptionSet_${timeStamp}'
  params: {
    autoKeyRotationEnabled: confidentialVMOSDiskEncryption ? false : true
    diskEncryptionSetName: confidentialVMOSDiskEncryption ? diskEncryptionSetNames.ConfidentialVMs : (diskEncryptionSetEncryptionType == 'EncryptionAtRestWithCustomerKey' ? diskEncryptionSetNames.CustomerManaged : diskEncryptionSetNames.PlatformAndCustomerManaged)
    encryptionType: diskEncryptionSetEncryptionType
    keyUrl: confidentialVMOSDiskEncryption ? confidentialVM_key_disks.outputs.value.KeyUriWithVersion : encryption_key_disks.outputs.keyUriWithVersion
    keyVaultResourceId: vmKeyVault.id
    location: location
    tags: contains(tags, 'Microsoft.Compute/diskEncryptionSets') ? tags['Microsoft.Compute/diskEncryptionSets'] : {}
    timeStamp: timeStamp
  }
}

output diskEncryptionSetResourceId string = diskEncryptionSet.outputs.resourceId
output storageEncryptionKeyKeyVaultUris array = [for i in range(0, storageCount): storageAccountKeyVaults[i].outputs.keyVaultUri ]
output storageKeyName string = storageAccountEncryptionKeyName
output encryptionUserAssignedIdentityResourceId string = userAssignedIdentity.outputs.resourceId
