metadata name = 'User Assigned Identities'
metadata description = 'This module deploys a User Assigned Identity.'
metadata owner = 'Azure/module-maintainers'

@description('Optional. Name of the User Assigned Identity.')
param name string = guid(resourceGroup().id)

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. The federated identity credentials list to indicate which token from the external IdP should be trusted by your application. Federated identity credentials are supported on applications only. A maximum of 20 federated identity credentials can be added per application object.')
param federatedIdentityCredentials array = []

@description('Optional. Tags of the resource.')
param tags object = {}

resource userMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

module userMsi_federatedIdentityCredentials 'federated-identity-credential/main.bicep' = [for (federatedIdentityCredential, index) in federatedIdentityCredentials: {
  name: '${uniqueString(deployment().name, location)}-UserMSI-FederatedIdentityCredential-${index}'
  params: {
    name: federatedIdentityCredential.name
    userAssignedIdentityName: userMsi.name
    audiences: federatedIdentityCredential.audiences
    issuer: federatedIdentityCredential.issuer
    subject: federatedIdentityCredential.subject
  }
}]

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

@description('The location the resource was deployed into.')
output location string = userMsi.location
