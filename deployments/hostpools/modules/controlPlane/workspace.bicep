param applicationGroupReferences array
param artifactsUserAssignedIdentityClientId string
param artifactsUri string
param deploymentUserAssignedIdentityClientId string
param existingWorkspace bool
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

module addApplicationGroups '../../../sharedModules/custom/customScriptExtension.bicep' = if (existingWorkspace && !empty(applicationGroupReferences)) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'AddApplicationGroupReferences_${timeStamp}'
  params: {
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Update-AvdWorkspace.ps1 -ApplicationGroupReferences "${applicationGroupReferences}" -Environment ${environment().name} -ResourceGroupName ${resourceGroup().name} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${deploymentUserAssignedIdentityClientId} -WorkspaceName ${workspaceName}'
    fileUris: [
      '${artifactsUri}Update-AvdWorkspace.ps1'
    ]
    location: locationVirtualMachines
    output: true
    tags: tags[?'Microsoft.Compute/virtualMachines'] ?? {}        
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = if (!existingWorkspace) { 
  name: workspaceName
  location: location
  tags: union({
    'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/Workspaces/${workspaceName}'
  }, tags[?'Microsoft.DesktopVirtualization/Workspaces'] ?? {})
  properties: {
    applicationGroupReferences: !empty(applicationGroupReferences) ? applicationGroupReferences : null
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
    serviceResourceId: existingWorkspace ? '' : workspace.id
    subnetResourceId: privateEndpointSubnetResourceId
    tags: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/hostpools/${workspaceName}'
    }, tags[?'Microsoft.Network/privateEndpoints'] ?? {}) 
  }
}

resource workspace_diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!existingWorkspace && enableMonitoring) {
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
