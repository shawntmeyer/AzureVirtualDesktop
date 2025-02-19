param name string
param location string
param privateEndpoints array
param tags object = {}

resource diskAccess 'Microsoft.Compute/diskAccesses@2021-04-01' = {
  name: name
  location: location
  tags: tags 
  properties: {}
}

module diskAccess_privateEndpoints '../../network/private-endpoint/main.bicep' = [for (privateEndpoint, index) in privateEndpoints: {
  name: 'DiskAccess-PrivateEndpoint-${index}-${uniqueString(deployment().name, location)}'
  params: {
    groupIds: [
      privateEndpoint.service
    ]
    name: privateEndpoint.?name ?? 'pe-${last(split(diskAccess.id, '/'))}-${privateEndpoint.service}-${index}'
    serviceResourceId: diskAccess.id
    subnetResourceId: privateEndpoint.subnetResourceId
    location: privateEndpoint.?location ?? reference(split(privateEndpoint.subnetResourceId, '/subnets/')[0], '2020-06-01', 'Full').location
    privateDnsZoneGroup: privateEndpoint.?privateDnsZoneGroup ?? {}
    tags: privateEndpoint.?tags ?? {}
    manualPrivateLinkServiceConnections: privateEndpoint.?manualPrivateLinkServiceConnections ?? []
    customDnsConfigs: privateEndpoint.?customDnsConfigs ?? []
    ipConfigurations: privateEndpoint.?ipConfigurations ?? []
    applicationSecurityGroups: privateEndpoint.?applicationSecurityGroups ?? []
    customNetworkInterfaceName: privateEndpoint.?customNetworkInterfaceName ?? ''
  }
}]

output resourceId string = diskAccess.id
