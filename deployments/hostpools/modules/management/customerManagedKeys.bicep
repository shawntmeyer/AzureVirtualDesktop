param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param confidentialVMOSDiskEncryption bool
param confidentialVMOrchestratorObjectId string
param deploymentUserAssignedIdentityClientId string
param diskEncryptionSetNames object
param diskEncryptionSetEncryptionType string
param environmentShortName string
param keyVaultNames object
param keyVaultPrivateDnsZoneResourceId string
param location string
param managementVirtualMachineName string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointSubnetId string
param tags object
param timeStamp string
param userAssignedIdentityNameConv string

var cseScriptParameters = confidentialVMOSDiskEncryption ? '-keyVaultName ${last(split(confidentialVMEncryptionKeysVault.outputs.keyVaultResourceId, '/'))} -keyName ConfidentialVMOSDiskEncryptionKey -Environment ${environment().name} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${deploymentUserAssignedIdentityClientId}' : ''

module encryptionKeysVault 'keyVault.bicep' = {
  name: 'KV_Encryption_${timeStamp}'
  params: {
    location: location
    environmentShortName: environmentShortName
    keyVaultName: keyVaultNames.RSAKeys
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointSubnetId: privateEndpointSubnetId
    skuName: 'standard'
    tagsKeyVault: contains(tags, 'Microsoft.KeyVault/vaults') ? tags['Microsoft.KeyVault/vaults'] : {}
    tagsPrivateEndpoints: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
  }
}

module confidentialVMEncryptionKeysVault 'keyVault.bicep' = if (confidentialVMOSDiskEncryption) {
  name: 'KV_ConfidentialVM_Encryption_${timeStamp}'
  params: {
    location: location
    environmentShortName: environmentShortName
    keyVaultName: keyVaultNames.RSAHSMKeys
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointSubnetId: privateEndpointSubnetId
    skuName: 'premium'
    tagsKeyVault: contains(tags, 'Microsoft.KeyVault/vaults') ? tags['Microsoft.KeyVault/vaults'] : {}
    tagsPrivateEndpoints: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
  }
}

module rsa_key_disks 'keyVaultKeys.bicep' = if (!confidentialVMOSDiskEncryption) {
  name: 'EncryptionKey_VMDiskEncryption_${timeStamp}'
  params: {
    exportable: false
    keyName: 'VMOSDiskEncryptionKey'
    keyType: 'RSA'
    keyVaultName: last(split(encryptionKeysVault.outputs.keyVaultResourceId, '/'))
    rotationPolicy: true
  }
}

module rsahsm_key_disks '../../../sharedModules/custom/customScriptExtension.bicep' = if(confidentialVMOSDiskEncryption) {
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

module key_storageAccounts 'keyVaultKeys.bicep' = {
  name: 'EncryptionKey_StorageAccounts_${timeStamp}'
  params: {
    exportable: false
    keyName: 'StorageAccountEncryptionKey'
    keyType: 'RSA'
    keyVaultName: last(split(encryptionKeysVault.outputs.keyVaultResourceId, '/'))
    rotationPolicy: true
  }
}

module userAssignedIdentity 'userAssignedIdentity.bicep' = {
  name: 'UAI_Encryption_${timeStamp}'
  params: {
    location: location
    name: replace(userAssignedIdentityNameConv, 'uaiPurpose', 'encryption')
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
    keyUrl: confidentialVMOSDiskEncryption ? rsahsm_key_disks.outputs.value.KeyUriWithVersion : rsa_key_disks.outputs.keyUriWithVersion
    keyVaultResourceId: confidentialVMOSDiskEncryption ? confidentialVMEncryptionKeysVault.outputs.keyVaultResourceId : encryptionKeysVault.outputs.keyVaultResourceId
    location: location
    tags: contains(tags, 'Microsoft.Compute/diskEncryptionSets') ? tags['Microsoft.Compute/diskEncryptionSets'] : {}
    timeStamp: timeStamp
  }
}

output diskEncryptionSetResourceId string = diskEncryptionSet.outputs.resourceId
output storagestorageEncryptionKeyKeyVaultUri string = encryptionKeysVault.outputs.keyVaultUri
output storageKeyName string = key_storageAccounts.outputs.keyName
output encryptionUserAssignedIdentityResourceId string = userAssignedIdentity.outputs.resourceId
