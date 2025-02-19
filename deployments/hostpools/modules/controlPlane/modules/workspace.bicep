param applicationGroupResourceId string
param deploymentUserAssignedIdentityClientId string
param existingWorkspaceResourceId string
param friendlyName string
param location string
param locationVirtualMachines string
param logAnalyticsWorkspaceResourceId string
param deploymentVirtualMachineName string
param enableMonitoring bool
param groupIds array
param privateDnsZoneResourceId string
param privateEndpoint bool
param privateEndpointLocation string
param privateEndpointName string
param privateEndpointNICName string
param publicNetworkAccess string
param privateEndpointSubnetResourceId string
param resourceGroupDeployment string
param tags object
param timeStamp string
param workspaceName string

module addApplicationGroup 'updateWorkspaceAppGroupReferences.bicep' = if (!empty(existingWorkspaceResourceId) && !empty(applicationGroupResourceId)) {
  name: 'Add_ApplicationGroup_Reference_${timeStamp}'
  scope: resourceGroup(resourceGroupDeployment)
  params: {
    applicationGroupResourceId: applicationGroupResourceId
    existingWorkspaceResourceId: existingWorkspaceResourceId
    userAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    location: locationVirtualMachines
    timeStamp: timeStamp
    virtualMachineName: deploymentVirtualMachineName
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = if (empty(existingWorkspaceResourceId)) {
  name: workspaceName
  location: location
  tags: tags[?'Microsoft.DesktopVirtualization/Workspaces'] ?? {}
  properties: {
    applicationGroupReferences: !empty(applicationGroupResourceId) ? [applicationGroupResourceId] : null
    friendlyName: friendlyName
    publicNetworkAccess: publicNetworkAccess
  }
}

module workspace_privateEndpoint '../../../../sharedModules/resources/network/private-endpoint/main.bicep' = if (privateEndpoint && !empty(privateEndpointSubnetResourceId)) {
  name: '${workspaceName}_privateEndpoint_${timeStamp}'
  params: {
    customNetworkInterfaceName: privateEndpointNICName
    groupIds: groupIds
    location: !empty(privateEndpointLocation) ? privateEndpointLocation : location
    name: privateEndpointName
    privateDnsZoneGroup: empty(privateDnsZoneResourceId) ? null : {
      privateDNSResourceIds: [
        privateDnsZoneResourceId
      ]
    }
    serviceResourceId: !empty(existingWorkspaceResourceId) ? existingWorkspaceResourceId : workspace.id
    subnetResourceId: privateEndpointSubnetResourceId
    tags: union(
      {
        'cm-resource-parent': workspace.id
      },
      tags[?'Microsoft.Network/privateEndpoints'] ?? {}
    )
  }
}

resource workspace_diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (empty(existingWorkspaceResourceId) && enableMonitoring) {
  name: 'WVDInsights'
  scope: workspace
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
