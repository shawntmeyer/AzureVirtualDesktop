param confidentialVMEncryptionKeysKeyVaultResourceId string
param confidentialVMOrchestratorObjectId string
param diskEncryptionKeyExpirationInDays int = 180
param encryptionKeyVaultResourceId string
param location string
param tags object
param timeStamp string
param userAssignedIdentityNameConv string

resource encryptionKeysVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: last(split(encryptionKeyVaultResourceId, '/'))
}

resource confidentialVMEncryptionKeysVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if(!empty(confidentialVMEncryptionKeysKeyVaultResourceId)) {
  name: last(split(confidentialVMEncryptionKeysKeyVaultResourceId, '/'))
}

resource rsa_key_disks 'Microsoft.KeyVault/vaults/keys@2022-07-01' = if(empty(confidentialVMEncryptionKeysKeyVaultResourceId)) {
  parent: encryptionKeysVault
  name: 'VMDiskEncryptionKey'
  properties: {
    attributes: {
      enabled: true
    }
    keySize: 4096
    kty: 'RSA'
    rotationPolicy: {
      attributes: {
        expiryTime: 'P${string(diskEncryptionKeyExpirationInDays)}D'
      }
      lifetimeActions: [
        {
          action: {
            type: 'Notify'
          }
          trigger: {
            timeBeforeExpiry: 'P10D'
          }
        }
        {
          action: {
            type: 'Rotate'
          }
          trigger: {
            timeAfterCreate: 'P${string(diskEncryptionKeyExpirationInDays - 7)}D'
          }
        }
      ]
    }
  }
}

resource rsa_hsm_key_disks 'Microsoft.KeyVault/vaults/keys@2022-07-01' = if(!empty(confidentialVMEncryptionKeysKeyVaultResourceId)){
  parent: confidentialVMEncryptionKeysVault
  name: 'ConfidentialVMDiskEncryptionKey'
  properties: {
    attributes: {
      enabled: true
      exportable: true
    }
    keySize: 4096
    kty: 'RSA-HSM'
  }
}

resource key_storageAccounts 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  parent: encryptionKeysVault
  name: 'StorageAccountEncryptionKey'
  properties: {
    attributes: {
      enabled: true
    }
    keySize: 4096
    kty: 'RSA'
    rotationPolicy: {
      attributes: {
        expiryTime: 'P${string(diskEncryptionKeyExpirationInDays)}D'
      }
      lifetimeActions: [
        {
          action: {
            type: 'Notify'
          }
          trigger: {
            timeBeforeExpiry: 'P10D'
          }
        }
        {
          action: {
            type: 'Rotate'
          }
          trigger: {
            timeAfterCreate: 'P${string(diskEncryptionKeyExpirationInDays - 7)}D'
          }
        }
      ]
    }
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

module roleAssignment_ConfVMOrchestrator_EncryptUser '../common/roleAssignment.bicep' = if(!empty(confidentialVMEncryptionKeysKeyVaultResourceId)) {
  name: 'RoleAssignment_ConfVMOrchestratorEncryptUser_${timeStamp}'
  params: {
    PrincipalId: confidentialVMOrchestratorObjectId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

module roleAssignment_ConfVMOrchestrator_ReleaseUser '../common/roleAssignment.bicep' = if(!empty(confidentialVMEncryptionKeysKeyVaultResourceId)) {
  name: 'RoleAssignment_ConfVMOrchestratorReleaseUser_${timeStamp}'
  params: {
    PrincipalId: confidentialVMOrchestratorObjectId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: '08bbd89e-9f13-488c-ac41-acfcb10c90ab' // Key Vault Crypto Service Release User
  }
}

output diskKeyUriWithVersion string = empty(confidentialVMEncryptionKeysKeyVaultResourceId) ? rsa_key_disks.properties.keyUriWithVersion : rsa_hsm_key_disks.properties.keyUriWithVersion
output diskKeyUri string = empty(confidentialVMEncryptionKeysKeyVaultResourceId) ? rsa_key_disks.properties.keyUri : rsa_hsm_key_disks.properties.keyUri
output storageKeyName string = key_storageAccounts.name
output encryptionUserAssignedIdentityClientId string = userAssignedIdentity.outputs.clientId
output encryptionUserAssignedIdentityPrincipalId string = userAssignedIdentity.outputs.principalId
output encryptionUserAssignedIdentityResourceId string = userAssignedIdentity.outputs.resourceId
