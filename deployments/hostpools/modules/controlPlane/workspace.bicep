param applicationGroupReferences array
param artifactsUserAssignedIdentityClientId string
param avdPrivateLink bool
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
param privateEndpointName string
param privateEndpointNICName string
param publicNetworkAccess string
param privateEndpointSubnetResourceId string
param resourceGroupManagement string
param tags object
param timeStamp string
param workspaceName string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = if (!empty(privateEndpointSubnetResourceId)) {
  name: split(privateEndpointSubnetResourceId, '/')[8]
  scope: resourceGroup(split(privateEndpointSubnetResourceId, '/')[2], split(privateEndpointSubnetResourceId, '/')[4])
}

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
    tags: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}    
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = if (!existingWorkspace) { 
  name: workspaceName
  location: location
  tags: union({
    'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/Workspaces/${workspaceName}'
  }, contains(tags, 'Microsoft.DesktopVirtualization/Workspaces') ? tags['Microsoft.DesktopVirtualization/Workspaces'] : {})
  properties: {
    applicationGroupReferences: !empty(applicationGroupReferences) ? applicationGroupReferences : null
    friendlyName: friendlyName
    publicNetworkAccess: publicNetworkAccess
  }
}

module privateEndpoint '../../../sharedModules/resources/network/private-endpoint/main.bicep' = if(avdPrivateLink && !empty(privateEndpointSubnetResourceId) && !empty(privateDnsZoneResourceId)) {
  name: '${workspaceName}_privateEndpoint_${timeStamp}'
  params: {
    customNetworkInterfaceName: privateEndpointNICName
    groupIds: groupIds
    location: vnet.location
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
    }, contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}) 
  }
}

resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!existingWorkspace && enableMonitoring) {
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
