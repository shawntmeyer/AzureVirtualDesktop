// this module is used to get the location of the private endpoint vnets so we can deploy the private endpoint to that location and avoid index errors when the privatEndpointSubnetResourceId is not provided.
targetScope = 'subscription'

param privateEndpointSubnetResourceId string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: split(privateEndpointSubnetResourceId, '/')[8]
  scope: resourceGroup(split(privateEndpointSubnetResourceId, '/')[2], split(privateEndpointSubnetResourceId, '/')[4])
}

output location string = vnet.location
