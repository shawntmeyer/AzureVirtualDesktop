param keyVaultName string
param keyName string

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource key 'Microsoft.KeyVault/vaults/keys@2023-07-01' existing = {
  name: keyName
  parent: keyVault
}

output keyUriWithVersion string = key.properties.keyUriWithVersion
