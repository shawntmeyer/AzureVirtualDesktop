param principalCount int
param roleDefinitionId string
param storageAccountName string
param objectIds array

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: storageAccountName
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, principalCount): {
  scope: storageAccount
  name: guid(objectIds[i], roleDefinitionId, storageAccount.id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: objectIds[i]
  }
}]
