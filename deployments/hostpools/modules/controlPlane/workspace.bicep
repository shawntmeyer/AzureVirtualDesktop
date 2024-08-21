param applicationGroupResourceId string
param deploymentUserAssignedIdentityClientId string
param existingWorkspaceResourceId string
param friendlyName string
param location string
param locationVirtualMachines string
param logAnalyticsWorkspaceResourceId string
param managementVirtualMachineName string
param enableMonitoring bool
param groupIds array
param privateDnsZoneResourceId string
param privateEndpoint bool
param privateEndpointLocation string
param privateEndpointName string
param privateEndpointNICName string
param publicNetworkAccess string
param privateEndpointSubnetResourceId string
param resourceGroupManagement string
param tags object
param timeStamp string
param workspaceName string

module addApplicationGroups '../../../sharedModules/resources/compute/virtual-machine/runCommand/main.bicep' = if (!empty(existingWorkspaceResourceId) && !empty(applicationGroupResourceId)) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'AddApplicationGroupReferences_${timeStamp}'
  params: {
    location: locationVirtualMachines
    name: 'AddApplicationGroupReferences'
    parameters: [
      {
        name: 'ApplicationGroupResourceId'
        value: applicationGroupResourceId
      }
      {
        name: 'ResourceManagerUri'
        value: environment().resourceManager
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: deploymentUserAssignedIdentityClientId
      }
      {
        name: 'WorkspaceResourceId'
        value: existingWorkspaceResourceId
      }
    ]
    script: loadTextContent('../../../../.common/scripts/Update-AvdWorkspaceAppReferences.ps1')
    treatFailureAsDeploymentFailure: true
    virtualMachineName: managementVirtualMachineName
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = if (empty(existingWorkspaceResourceId)) { 
  name: workspaceName
  location: location
  tags: union({
    'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/Workspaces/${workspaceName}'
  }, tags[?'Microsoft.DesktopVirtualization/Workspaces'] ?? {})
  properties: {
    applicationGroupReferences: !empty(applicationGroupResourceId) ? [ applicationGroupResourceId ] : null
    friendlyName: friendlyName
    publicNetworkAccess: publicNetworkAccess
  }
}

module workspace_privateEndpoint '../../../sharedModules/resources/network/private-endpoint/main.bicep' = if(privateEndpoint && !empty(privateEndpointSubnetResourceId) && !empty(privateDnsZoneResourceId)) {
  name: '${workspaceName}_privateEndpoint_${timeStamp}'
  params: {
    customNetworkInterfaceName: privateEndpointNICName
    groupIds: groupIds
    location: !empty(privateEndpointLocation) ? privateEndpointLocation : location
    name: privateEndpointName
    privateDnsZoneGroup: {
      privateDNSResourceIds: [
        privateDnsZoneResourceId
      ]
    }
    serviceResourceId: !empty(existingWorkspaceResourceId) ? '' : workspace.id
    subnetResourceId: privateEndpointSubnetResourceId
    tags: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/hostpools/${workspaceName}'
    }, tags[?'Microsoft.Network/privateEndpoints'] ?? {}) 
  }
}

resource workspace_diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (empty(existingWorkspaceResourceId) && enableMonitoring) {
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
