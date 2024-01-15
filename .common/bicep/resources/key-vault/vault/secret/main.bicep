metadata name = 'Key Vault Secrets'
metadata description = 'This module deploys a Key Vault Secret.'
metadata owner = 'Azure/module-maintainers'

@description('Conditional. The name of the parent key vault. Required if the template is used in a standalone deployment.')
param keyVaultName string

@description('Required. The name of the secret.')
param name string

@description('Optional. Resource tags.')
param tags object = {}

@description('Optional. Determines whether the object is enabled.')
param attributesEnabled bool = true

@description('Optional. Expiry date in seconds since 1970-01-01T00:00:00Z. For security reasons, it is recommended to set an expiration date whenever possible.')
param attributesExp int = -1

@description('Optional. Not before date in seconds since 1970-01-01T00:00:00Z.')
param attributesNbf int = -1

@description('Optional. The content type of the secret.')
@secure()
param contentType string = ''

@description('Required. The value of the secret. NOTE: "value" will never be returned from the service, as APIs using this model are is intended for internal use in ARM deployments. Users should use the data-plane REST service for interaction with vault secrets.')
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

@description('The name of the secret.')
output name string = secret.name

@description('The resource ID of the secret.')
output resourceId string = secret.id

@description('The name of the resource group the secret was created in.')
output resourceGroupName string = resourceGroup().name
