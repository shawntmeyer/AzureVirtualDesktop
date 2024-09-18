targetScope = 'subscription'

param userAssignedIdentityResourceId string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: last(split(userAssignedIdentityResourceId ,'/'))
  scope: resourceGroup(split(userAssignedIdentityResourceId, '/')[2], split(userAssignedIdentityResourceId, '/')[4])
}

output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
