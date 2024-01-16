param desktopApplicationGroupName string
param hostPoolResourceId string
param location string
param roleDefinitions object
param securityPrincipalObjectIds array
param tags object

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