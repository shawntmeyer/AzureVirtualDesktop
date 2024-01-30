param exportable bool
param keyName string
param keyType string
param keyVaultName string
param rotationPolicy bool
param diskEncryptionKeyExpirationInDays int = 180

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource key 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  parent: vault
  name: keyName
  properties: {
    attributes: {
      enabled: true
      exportable: exportable ? true : null
    }
    keySize: 4096
    kty: keyType
    rotationPolicy: rotationPolicy ? {
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
    } : null
  }
}

output diskKeyUri string = key.properties.keyUri
output diskKeyUriWithVersion string = key.properties.keyUriWithVersion
