targetScope = 'subscription'

param storageResourceIds array

resource storageAccounts 'Microsoft.Storage/storageAccounts@2023-01-01' existing = [for id in storageResourceIds: {
  name: last(split(id, '/'))
  scope: resourceGroup(split(id, '/')[2], split(id, '/')[4])
}]


output storageAccounts array = [for i in range(0,length(storageResourceIds)): {
  name: storageAccounts[i].name
  location: storageAccounts[i].location
  id: storageAccounts[i].id
}]
