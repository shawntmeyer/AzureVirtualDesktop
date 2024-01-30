param confidentialVMOSDiskEncryption bool
param confidentialVMOrchestratorObjectId string
param diskEncryptionSetNames object
param diskEncryptionSetEncryptionType string
param environmentShortName string
param keyVaultNames object
param keyVaultPrivateDnsZoneResourceId string
param location string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointSubnetId string
param tags object
param timeStamp string
param userAssignedIdentityNameConv string

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
  name: 'KV_Encryption_${timeStamp}'
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

module rsa_key_disks 'keyVaultKeys.bicep' = if(!confidentialVMOSDiskEncryption) {
  name: 'VMOSDiskEncryptionKey_${timeStamp}'
  params: {
    exportable: false
    keyName: 'VMOSDiskEncryptionKey'
    keyType: 'RSA'
    keyVaultName: last(split(encryptionKeysVault.outputs.keyVaultResourceId, '/'))
    rotationPolicy: true
  }
}

module rsahsm_key_disks 'keyVaultKeys.bicep' = if(confidentialVMOSDiskEncryption) {
  name: 'ConfidentialVMOSDiskEncryptionKey_${timeStamp}'
  params: {
    exportable: true
    keyName: 'ConfidentialVMOSDiskEncryptionKey'
    keyType: 'RSA-HSM'
    keyVaultName: confidentialVMOSDiskEncryption ? last(split(confidentialVMEncryptionKeysVault.outputs.keyVaultResourceId, '/')) : ''
    rotationPolicy: false
  }
}

module key_storageAccounts 'keyVaultKeys.bicep' = {
  name: 'StorageAccountEncryptionKey_${timeStamp}'
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

module roleAssignment_UAI_EncryptUser '../common/roleAssignment.bicep' = {
  name: 'RoleAssignment_Encryption_${timeStamp}'
  params: {
    PrincipalId: userAssignedIdentity.outputs.principalId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

module roleAssignment_ConfVMOrchestrator_EncryptUser '../common/roleAssignment.bicep' = if(confidentialVMOSDiskEncryption) {
  name: 'RoleAssignment_ConfVMOrchestratorEncryptUser_${timeStamp}'
  params: {
    PrincipalId: confidentialVMOrchestratorObjectId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

module roleAssignment_ConfVMOrchestrator_ReleaseUser '../common/roleAssignment.bicep' = if(confidentialVMOSDiskEncryption) {
  name: 'RoleAssignment_ConfVMOrchestratorReleaseUser_${timeStamp}'
  params: {
    PrincipalId: confidentialVMOrchestratorObjectId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: '08bbd89e-9f13-488c-ac41-acfcb10c90ab' // Key Vault Crypto Service Release User
  }
}

module diskEncryptionSet 'diskEncryptionSet.bicep' = {
  name: 'DiskEncryptionSet_${timeStamp}'
  params: {
    diskEncryptionSetName: confidentialVMOSDiskEncryption ? diskEncryptionSetNames.ConfidentialVMs : ( diskEncryptionSetEncryptionType == 'EncryptionAtRestWithCustomerKey' ? diskEncryptionSetNames.CustomerManaged : diskEncryptionSetNames.PlatformAndCustomerManaged )
    encryptionType: diskEncryptionSetEncryptionType
    keyUrl: confidentialVMOSDiskEncryption ? rsahsm_key_disks.outputs.keyUriWithVersion : rsa_key_disks.outputs.keyUriWithVersion
    keyVaultResourceId: confidentialVMOSDiskEncryption ? confidentialVMEncryptionKeysVault.outputs.keyVaultResourceId : encryptionKeysVault.outputs.keyVaultResourceId
    location: location
    tags: contains(tags, 'Microsoft.Compute/diskEncryptionSets') ? tags['Microsoft.Compute/diskEncryptionSets'] : {}
    timeStamp: timeStamp
  }
}

//output diskEncryptionKeyUrl string = confidentialVMOSDiskEncryption ? rsahsm_key_disks.outputs.keyUri : rsa_key_disks.outputs.keyUri
output diskEncryptionSetResourceId string = diskEncryptionSet.outputs.resourceId
output storagestorageEncryptionKeyKeyVaultUri string = encryptionKeysVault.outputs.keyVaultUri
output storageKeyName string = key_storageAccounts.outputs.keyName
output encryptionUserAssignedIdentityClientId string = userAssignedIdentity.outputs.clientId
output encryptionUserAssignedIdentityPrincipalId string = userAssignedIdentity.outputs.principalId
output encryptionUserAssignedIdentityResourceId string = userAssignedIdentity.outputs.resourceId
