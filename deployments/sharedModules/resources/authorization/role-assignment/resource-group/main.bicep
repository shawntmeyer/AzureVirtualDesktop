@sys.description('''Required. You can provide either the role definition GUID or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.
You can find the GUIDs in the ID column on the table at https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles.
''')
param roleDefinitionId string

@sys.description('Required. The Principal or Object ID of the Security Principal (User, Group, Service Principal, Managed Identity).')
param principalId string

@sys.description('Optional. Name of the Resource Group to assign the RBAC role to. If not provided, will use the current scope for deployment.')
param resourceGroupName string = resourceGroup().name

@sys.description('Optional. Subscription ID of the subscription to assign the RBAC role to. If not provided, will use the current scope for deployment.')
param subscriptionId string = subscription().subscriptionId

@sys.description('Optional. The principal type of the assigned principal ID.')
@allowed([
  'ServicePrincipal'
  'Group'
  'User'
  'ForeignGroup'
  'Device'
  ''
])
param principalType string = ''

var roleDefinitionIdVar = (contains(roleDefinitionId, '/providers/Microsoft.Authorization/roleDefinitions/')) ? roleDefinitionId : '/providers/Microsoft.Authorization/roleDefinitions/${roleDefinitionId}'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscriptionId, resourceGroupName, roleDefinitionIdVar, principalId)
  properties: {
    roleDefinitionId: roleDefinitionIdVar
    principalId: principalId
    principalType: !empty(principalType) ? any(principalType) : null
  }
}

output resourceId string = roleAssignment.id
