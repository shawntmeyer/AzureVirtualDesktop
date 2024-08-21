param adminCount int
param adminRoleDefinitionId string
param storageAccountName string
param fslogixAdminGroupObjectIds array

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: storageAccountName
}

resource roleAssignmentsAdmins 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, adminCount): {
  scope: storageAccount
  name: guid(fslogixAdminGroupObjectIds[i], adminRoleDefinitionId, storageAccount.id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', adminRoleDefinitionId)
    principalId: fslogixAdminGroupObjectIds[i]
  }
}]
