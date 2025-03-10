param name string
param location string = resourceGroup().location
param tags object = {}

resource userMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output name string = userMsi.name
output resourceId string = userMsi.id
output principalId string = userMsi.properties.principalId
output clientId string = userMsi.properties.clientId
