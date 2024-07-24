param diskAccessName string
param location string
param privateDNSZoneResourceId string
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param tags object
param timeStamp string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = if (!empty(privateEndpointSubnetResourceId)) {
  name: split(privateEndpointSubnetResourceId, '/')[8]
  scope: resourceGroup(split(privateEndpointSubnetResourceId, '/')[2], split(privateEndpointSubnetResourceId, '/')[4])
}

resource diskAccess 'Microsoft.Compute/diskAccesses@2021-04-01' = {
  name: diskAccessName
  location: location
  tags: contains(tags, 'Microsoft.Compute/diskAccesses') ? tags['Microsoft.Compute/diskAccesses'] : {} 
  properties: {}
}

module diskAccess_privateEndpoint '../../../sharedModules/resources/network/private-endpoint/main.bicep' = {
  name: '${diskAccessName}_privateEndpoint_${timeStamp}'
  params: {
    customNetworkInterfaceName: replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'disks'), 'RESOURCE', diskAccessName), 'VNETID', '${split(privateEndpointSubnetResourceId, '/')[8]}')
    groupIds: [
      'disks'
    ]
    location: vnet.location
    name: replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'disks'), 'RESOURCE', diskAccessName), 'VNETID', '${split(privateEndpointSubnetResourceId, '/')[8]}')
    privateDnsZoneGroup: {
      privateDNSResourceIds: [
        privateDNSZoneResourceId
      ]
    }
    serviceResourceId: diskAccess.id
    subnetResourceId: privateEndpointSubnetResourceId
    tags: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
  }
}

output resourceId string = diskAccess.id
