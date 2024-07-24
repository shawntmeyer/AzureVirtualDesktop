metadata name = 'Resolve Storage Account Resource Ids'
metadata description = 'This module takes two arrays of storage account resource Ids and compares them against fslogix configuration requirements to output a reconciled list of storage account resource Ids for the Session Host Fslogix configuration script.'
metadata owner = 'Shawn Meyer, Microsoft Corporation'

targetScope = 'subscription'

param deployedStorageAccountResourceIds array
param existingStorageAccountResourceIds array
param location string
param fslogixContainerType string
param timeStamp string

// There are 2 main scenarios to consider when determining the storage account resource ids for the fslogix configuration script.

// 1. EntraId and VHD Location: This scenario has a restriction of 1 storage account per region and no more than 1 storage account total.
// 2. EntraId and Cloud Cache: This scenario has a restriction of 1 storage account per region and no more than 4 storage accounts total.

// dedup the storage account resource ids.
var storageAccountResourceIds = union(deployedStorageAccountResourceIds, existingStorageAccountResourceIds)

// for EntraId we can only use 1 storage account per region so we must dedup by region keeping only the first storage account per region
// first get the reference to the storage accounts so we can create and array of objects containing the region and the storage account resource id
resource storageAccounts 'Microsoft.Storage/storageAccounts@2023-01-01' existing = [for id in storageAccountResourceIds: {
  name: last(split(id, '/'))
  scope: resourceGroup(split(id, '/')[2], split(id, '/')[4])
}]

// then create an array of objects containing the region and the storage account resource id
module entraIdStorageAccounts 'filterUniqueRegion.bicep' = {
  name: 'aadVhdStorageAccounts_${timeStamp}'
  params: {
    location: location
    storageAccounts: [for i in range(0,length(storageAccountResourceIds)): {
      location: storageAccounts[i].location
      id: storageAccounts[i].id
    }]
  }
}

output storageAccountResourceIds array = contains(fslogixContainerType, 'CloudCache') ? entraIdStorageAccounts.outputs.ccStorageAccountIds : entraIdStorageAccounts.outputs.vhdStorageAccountId
