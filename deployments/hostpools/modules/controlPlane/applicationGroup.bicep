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
param securityPrincipals array
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
  }, tags[?'Microsoft.DesktopVirtualization/applicationGroups'] ?? {})
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
module updateDesktopFriendlyName '../../../sharedModules/resources/compute/virtual-machine/runCommand/main.bicep' = if (!empty(desktopFriendlyName)) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'DesktopFriendlyName_${timeStamp}'
  params : {
    location: locationVirtualMachines
    name: 'DesktopFriendlyName'
    script: loadTextContent('../../../../.common/scripts/Update-AvdSessionDesktopName.ps1')
    parameters: [
      {
        name: 'ApplicationGroupResourceId'
        value: applicationGroup.id
      }
      {
        name: 'FriendlyName'
        value: desktopFriendlyName
      }
      {
        name: 'ResourceManagerUri'
        value: environment().resourceManager
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: deploymentUserAssignedIdentityClientId
      }
    ]
    treatFailureAsDeploymentFailure: true
    virtualMachineName: managementVirtualMachineName
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, length(securityPrincipals)): {
  scope: applicationGroup
  name: guid(securityPrincipals[i], roleDefinitions.DesktopVirtualizationUser, desktopApplicationGroupName)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.DesktopVirtualizationUser)
    principalId: securityPrincipals[i]
  }
}]

output Name string = applicationGroup.name
output ApplicationGroupResourceId string = applicationGroup.id
