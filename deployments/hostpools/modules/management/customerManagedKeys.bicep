param diskEncryptionKeyExpirationInDays int = 180
param diskEncryptionOptions object
param keyVaultResourceId string
param location string
param tags object
param timeStamp string
param userAssignedIdentityNameConv string

resource vault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: last(split(keyVaultResourceId, '/'))
}

resource key_disks 'Microsoft.KeyVault/vaults/keys@2022-07-01' = if(diskEncryptionOptions.keyEncryptionKey || diskEncryptionOptions.diskEncryptionSet){
  parent: vault
  name: diskEncryptionOptions.diskEncryptionSet ? 'DiskEncryptionKey' : 'ADEkeyEncryptionKey'
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

resource key_storageAccounts 'Microsoft.KeyVault/vaults/keys@2022-07-01' = if(diskEncryptionOptions.storageEncryptionKey) {
  parent: vault
  name: 'StorageEncryptionKey'
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

module roleAssignment '../roleAssignment.bicep' = {
  name: 'RoleAssignment_Encryption_${timeStamp}'
  params: {
    PrincipalId: userAssignedIdentity.outputs.principalId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

output diskKeyUriWithVersion string = diskEncryptionOptions.keyEncryptionKey || diskEncryptionOptions.diskEncryptionSet ? key_disks.properties.keyUriWithVersion : ''
output diskKeyUri string = diskEncryptionOptions.keyEncryptionKey || diskEncryptionOptions.diskEncryptionSet ? key_disks.properties.keyUri : ''
output keyVaultResourceId string = vault.id
output keyVaultUri string = vault.properties.vaultUri
output storageKeyName string = diskEncryptionOptions.storageEncryptionKey ? key_storageAccounts.name : ''
output encryptionUserAssignedIdentityClientId string = userAssignedIdentity.outputs.clientId
output encryptionUserAssignedIdentityPrincipalId string = userAssignedIdentity.outputs.principalId
output encryptionUserAssignedIdentityResourceId string = userAssignedIdentity.outputs.resourceId
