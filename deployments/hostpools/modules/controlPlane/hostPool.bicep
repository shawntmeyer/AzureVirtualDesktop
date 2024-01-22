param identitySolution string
param avdPrivateLink bool
param hostPoolPrivateDnsZoneResourceId string
param hostPoolRDPProperties string
param hostPoolName string
param hostPoolPublicNetworkAccess string
param hostPoolType string
param location string
param logAnalyticsWorkspaceResourceId string
param privateEndpointName string
param privateEndpointSubnetResourceId string
param hostPoolMaxSessionLimit int
param monitoring bool
param tags object
param time string = utcNow('u')
param hostPoolValidationEnvironment bool
param virtualMachineTemplate string

var customRdpProperty = !contains(identitySolution, 'DomainServices') && !contains(hostPoolRDPProperties, 'targetisaadjoined:i:1') ? '${hostPoolRDPProperties};targetisaadjoined:i:1' : hostPoolRDPProperties

var HostPoolLogs = [
  {
    category: 'Checkpoint'
    enabled: true
  }
  {
    category: 'Error'
    enabled: true
  }
  {
    category: 'Management'
    enabled: true
  }
  {
    category: 'Connection'
    enabled: true
  }
  {
    category: 'HostRegistration'
    enabled: true
  }
  {
    category: 'AgentHealthStatus'
    enabled: true
  }
]

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: location
  tags: union({
    'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'
  }, contains(tags, 'Microsoft.DesktopVirtualization/hostPools') ? tags['Microsoft.DesktopVirtualization/hostPools'] : {})
  properties: {
    hostPoolType: split(hostPoolType, ' ')[0]
    maxSessionLimit: hostPoolMaxSessionLimit
    loadBalancerType: contains(hostPoolType, 'Pooled') ? split(hostPoolType, ' ')[1] : 'Persistent'
    validationEnvironment: hostPoolValidationEnvironment
    registrationInfo: {
      expirationTime: dateTimeAdd(time, 'PT2H')
      registrationTokenOperation: 'Update'
    }
    preferredAppGroupType: 'Desktop'
    customRdpProperty: customRdpProperty
    personalDesktopAssignmentType: contains(hostPoolType, 'Personal') ? split(hostPoolType, ' ')[1] : null
    publicNetworkAccess: hostPoolPublicNetworkAccess
    startVMOnConnect: true
    vmTemplate: virtualMachineTemplate
  }
}

resource hostPoolPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = if(avdPrivateLink) {
  name: privateEndpointName
  location: location
  tags: union({
    'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'
  }, contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {})
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        id: resourceId('Microsoft.Network/privateEndpoints/privateLinkServiceConnections', privateEndpointName, privateEndpointName)
        properties: {
          privateLinkServiceId: hostPool.id
          groupIds: [
            'connection'
          ]
        }
      }
    ]
    customNetworkInterfaceName: 'nic-${hostPoolName}'
    subnet: {
      id: privateEndpointSubnetResourceId
    }
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = if(avdPrivateLink && !empty(hostPoolPrivateDnsZoneResourceId)) {
  parent: hostPoolPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace(split(hostPoolPrivateDnsZoneResourceId, '/')[8], '.', '-')
        properties: {
          privateDnsZoneId: hostPoolPrivateDnsZoneResourceId
        }
      }
    ]
  }
}

resource hostPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (monitoring) {
  name: 'diag-${hostPoolName}'
  scope: hostPool
  properties: {
    logs: HostPoolLogs
    workspaceId: logAnalyticsWorkspaceResourceId
  }
}

output ResourceId string = hostPool.id
