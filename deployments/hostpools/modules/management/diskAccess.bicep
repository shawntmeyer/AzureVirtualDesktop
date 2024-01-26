param diskAccessName string
param location string
param privateEndpointNameConv string
param subnetResourceId string
param tags object

var privateEndpointName = replace(privateEndpointNameConv, 'resource', diskAccessName)

resource diskAccess 'Microsoft.Compute/diskAccesses@2021-04-01' = {
  name: diskAccessName
  location: location
  tags: contains(tags, 'Microsoft.Compute/diskAccesses') ? tags['Microsoft.Compute/diskAccesses'] : {} 
  properties: {}
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2019-04-01' = {
  name: privateEndpointName
  location: location
  tags: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pe-${diskAccessName}'
        properties: {
          privateLinkServiceId: diskAccess.id
          groupIds: [
            'disks'
          ]
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: subnetResourceId
    }
  }
}


output resourceId string = diskAccess.id
