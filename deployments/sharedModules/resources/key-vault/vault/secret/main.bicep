param keyVaultName string
param name string
param tags object = {}
param attributesEnabled bool = true
param attributesExp int = -1
param attributesNbf int = -1
@secure()
param contentType string = ''
@secure()
param value string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: name
  parent: keyVault
  tags: tags
  properties: {
    contentType: contentType
    attributes: {
      enabled: attributesEnabled
      exp: attributesExp != -1 ? attributesExp : null
      nbf: attributesNbf != -1 ? attributesNbf : null
    }
    value: value
  }
}

output name string = secret.name
output resourceId string = secret.id
