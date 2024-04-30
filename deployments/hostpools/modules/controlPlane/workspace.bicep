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
param privateDnsZoneResourceId string
param privateEndpointName string
param publicNetworkAccess string
param privateEndpointSubnetResourceId string
param resourceGroupManagement string
param tags object
param timeStamp string
param workspaceName string

module addApplicationGroups '../../../sharedModules/custom/customScriptExtension.bicep' = if (existingWorkspace) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'AddApplicationGroupReferences_${timeStamp}'
  params: {
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -command .\\Update-AvdWorkspace.ps1 -ApplicationGroupReferences "${applicationGroupReferences}" -Environment ${environment().name} -ResourceGroupName ${resourceGroup().name} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${deploymentUserAssignedIdentityClientId} -WorkspaceName ${workspaceName}'
    fileUris: [
      '${artifactsUri}Update-AvdWorkspace.ps1'
    ]
    location: locationVirtualMachines
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
    applicationGroupReferences: applicationGroupReferences
    friendlyName: friendlyName
    publicNetworkAccess: publicNetworkAccess
  }
}

resource private_Endpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = if (!existingWorkspace && avdPrivateLink) {
  name: privateEndpointName
  location: location
  tags: union({
    'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DesktopVirtualization/Workspaces/${workspaceName}'
  }, contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {})
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        id: resourceId('Microsoft.Network/privateEndpoints/privateLinkServiceConnections', privateEndpointName, privateEndpointName)
        properties: {
          privateLinkServiceId: workspace.id
          groupIds: [
            'feed'
          ]
        }
      }
    ]
    customNetworkInterfaceName: 'nic-${workspaceName}'
    subnet: {
      id: privateEndpointSubnetResourceId
    }
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = if (!existingWorkspace && !empty(privateDnsZoneResourceId)) {
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
