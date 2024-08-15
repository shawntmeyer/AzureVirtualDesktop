param applicationGroups array
param avdPrivateLink bool
param existing bool
param friendlyName string
param logAnalyticsWorkspaceResourceId string
param enableMonitoring bool
param privateDnsZoneResourceId string
param privateEndpointName string
param privateEndpointNICName string
param publicNetworkAccess string
param privateEndpointSubnetResourceId string
param tags object
param workspaceName string

var applicationGroupReferences = union(existing_Workspace.properties.applicationGroupReferences, applicationGroups)

resource existing_Workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = if(existing) {
  name: workspaceName
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  tags: union({
    'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/Workspaces/${workspaceName}'
  }, tags[?'Microsoft.DesktopVirtualization/Workspaces'] ?? {})
  properties: {
    applicationGroupReferences: applicationGroupReferences
    friendlyName: friendlyName
    publicNetworkAccess: publicNetworkAccess
  }
}

resource private_Endpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = if (!existing && avdPrivateLink) {
  name: privateEndpointName
  tags: union({
    'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/Workspaces/${workspaceName}'
  }, tags[?'Microsoft.Network/privateEndpoints'] ?? {})
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${workspaceName}-feed'
        properties: {
          privateLinkServiceId: workspace.id
          groupIds: [
            'feed'
          ]
        }
      }
    ]
    customNetworkInterfaceName: privateEndpointNICName
    subnet: {
      id: privateEndpointSubnetResourceId
    }
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = if (!existing && !empty(privateDnsZoneResourceId)) {
  parent: private_Endpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace(split(privateDnsZoneResourceId, '/')[8], '.', '-')
        properties: {
          privateDnsZoneId: privateDnsZoneResourceId
        }
      }
    ]
  }
}

resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableMonitoring) {
  name: 'diag-${workspaceName}'
  scope: workspace
  properties: {
    logs: [
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
        category: 'Feed'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspaceResourceId
  }
}
