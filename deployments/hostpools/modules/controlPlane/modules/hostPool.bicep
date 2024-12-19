param identitySolution string
param privateEndpoint bool
param hostPoolPrivateDnsZoneResourceId string
param hostPoolRDPProperties string
param hostPoolName string
param hostPoolPublicNetworkAccess string
param hostPoolType string
param location string
param logAnalyticsWorkspaceResourceId string
param privateEndpointLocation string
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

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: location
  tags: union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/hostPools/${hostPoolName}'}, tags[?'Microsoft.DesktopVirtualization/hostPools'] ?? {})
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

module hostPool_PrivateEndpoint '../../../../sharedModules/resources/network/private-endpoint/main.bicep' = if(privateEndpoint && !empty(privateEndpointSubnetResourceId)) {
  name: '${hostPoolName}_privateEndpoint_${timeStamp}'
  params: {
    customNetworkInterfaceName: privateEndpointNICName
    groupIds: [
      'connection'
    ]
    location: !empty(privateEndpointLocation) ? privateEndpointLocation : location
    name: privateEndpointName
    privateDnsZoneGroup: empty(hostPoolPrivateDnsZoneResourceId) ? null : {
      privateDNSResourceIds: [
        hostPoolPrivateDnsZoneResourceId
      ]
    }
    serviceResourceId: hostPool.id
    subnetResourceId: privateEndpointSubnetResourceId
    tags: union({
      'cm-resource-parent': hostPool.id
    }, tags[?'Microsoft.Network/privateEndpoints'] ?? {}) 
  }
}

resource hostPool_Diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableMonitoring) {
  name: 'WVDInsights'
  scope: hostPool
  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    workspaceId: logAnalyticsWorkspaceResourceId
  }
}

output resourceId string = hostPool.id
