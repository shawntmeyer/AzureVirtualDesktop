param name string
param location string = resourceGroup().location
param tags object = {}

resource userMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

@description('The name of the user assigned identity.')
output name string = userMsi.name

@description('The resource ID of the user assigned identity.')
output resourceId string = userMsi.id

@description('The principal ID (object ID) of the user assigned identity.')
output principalId string = userMsi.properties.principalId

@description('The client ID (application ID) of the user assigned identity.')
output clientId string = userMsi.properties.clientId

@description('The resource group the user assigned identity was deployed into.')
output resourceGroupName string = resourceGroup().name
