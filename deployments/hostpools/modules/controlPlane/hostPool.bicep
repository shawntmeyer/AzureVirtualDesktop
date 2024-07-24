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
param privateEndpointNICName string
param privateEndpointSubnetResourceId string
param hostPoolMaxSessionLimit int
param enableMonitoring bool
param tags object
param timeStamp string
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

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = if (!empty(privateEndpointSubnetResourceId)) {
  name: split(privateEndpointSubnetResourceId, '/')[8]
  scope: resourceGroup(split(privateEndpointSubnetResourceId, '/')[2], split(privateEndpointSubnetResourceId, '/')[4])
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: location
  tags: union({
    'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/hostPools/${hostPoolName}'
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

module privateEndpoint '../../../sharedModules/resources/network/private-endpoint/main.bicep' = if(avdPrivateLink && !empty(privateEndpointSubnetResourceId)) {
  name: '${hostPoolName}_privateEndpoint_${timeStamp}'
  params: {
    customNetworkInterfaceName: privateEndpointNICName
    groupIds: [
      'connection'
    ]
    location: vnet.location
    name: privateEndpointName
    privateDnsZoneGroup: {
      privateDNSResourceIds: [
        hostPoolPrivateDnsZoneResourceId
      ]
    }
    serviceResourceId: hostPool.id
    subnetResourceId: privateEndpointSubnetResourceId
    tags: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/hostPools/${hostPoolName}'
    }, contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}) 
  }
}

resource hostPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableMonitoring) {
  name: 'diag-${hostPoolName}'
  scope: hostPool
  properties: {
    logs: HostPoolLogs
    workspaceId: logAnalyticsWorkspaceResourceId
  }
}

output resourceId string = hostPool.id
output registrationToken string = reference(hostPool.id).registrationInfo.token
