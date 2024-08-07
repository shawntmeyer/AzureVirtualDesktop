param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param deploymentUserAssignedIdentityClientId string
param desktopApplicationGroupName string
param desktopFriendlyName string
param hostPoolResourceId string
param location string
param locationVirtualMachines string
param logAnalyticsWorkspaceResourceId string
param managementVirtualMachineName string
param roleDefinitions object
param resourceGroupManagement string
param securityPrincipalObjectIds array
param tags object
param timeStamp string

var applicationGroupLogs = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2021-03-09-preview' = {
  name: desktopApplicationGroupName
  location: location
  tags: union({
    'cm-resource-parent': hostPoolResourceId
  }, contains(tags, 'Microsoft.DesktopVirtualization/applicationGroups') ? tags['Microsoft.DesktopVirtualization/applicationGroups'] : {})
  properties: {
    hostPoolArmPath: hostPoolResourceId
    applicationGroupType: 'Desktop'
  }
}

resource applicationGroup_DiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(!empty(logAnalyticsWorkspaceResourceId)) {
  name: 'diag-${desktopApplicationGroupName}'
  scope: applicationGroup
  properties: {
    logs: applicationGroupLogs
    workspaceId: logAnalyticsWorkspaceResourceId
  }
}

// Adds a friendly name to the SessionDesktop application for the desktop application group
module applicationFriendlyName '../../../sharedModules/custom/customScriptExtension.bicep' = if (!empty(desktopFriendlyName)) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'DesktopFriendlyName_${timeStamp}'
  params : {
    commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Update-AvdDesktop.ps1 -ApplicationGroupName ${applicationGroup.name} -Environment ${environment().name} -FriendlyName "${desktopFriendlyName}" -ResourceGroupName ${resourceGroup().name} -SubscriptionId ${subscription().subscriptionId} -Tenant ${tenant().tenantId} -UserAssignedIdentityClientId ${deploymentUserAssignedIdentityClientId}'
    fileUris: [
      '${artifactsUri}Update-AvdDesktop.ps1'
    ]
    location: locationVirtualMachines
    output: true
    tags: union({
      'cm-resource-parent': hostPoolResourceId
    }, contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {})
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, length(securityPrincipalObjectIds)): {
  scope: applicationGroup
  name: guid(securityPrincipalObjectIds[i], roleDefinitions.DesktopVirtualizationUser, desktopApplicationGroupName)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.DesktopVirtualizationUser)
    principalId: securityPrincipalObjectIds[i]
  }
}]

output ApplicationGroupReference array = [
  applicationGroup.id
]
output Name string = applicationGroup.name
output ResourceId string = applicationGroup.id
