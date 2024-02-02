metadata name = 'Resolve Storage Account Resource Ids'
metadata description = 'This module takes two arrays of storage account resource Ids and compares them against fslogix configuration requirements to output a reconciled list of storage account resource Ids for the Session Host Fslogix configuration script.'
metadata owner = 'Shawn Meyer, Microsoft Corporation'

targetScope = 'subscription'

param deployedStorageAccountResourceIds array
param existingStorageAccountResourceIds array
param fslogixContainerType string
param identitySolution string

// There are 4 main scenarios to consider when determining the storage account resource ids for the fslogix configuration script.

// 1. Domain Services with VHD Containers: This scenario has no restrictions on the number of storage accounts or number per region.
// 2. Domain Services with Cloud Cache: This scenario has a restriction of 4 storage accounts for the cloud cache configuration.
// 3. EntraId and VHD Location: This scenario has a restriction of 1 storage account per region and no more than 4 storage accounts total.
// 4. EntraId and Cloud Cache: This scenario has a restriction of 1 storage account per region and no more than 4 storage accounts total.

// dedup the storage account resource ids. This will be the only anaylsis done for Scenario 1.
var storageAccountResourceIds = union(deployedStorageAccountResourceIds, existingStorageAccountResourceIds)

// Scenario 2: Domain Services with Cloud Cache
var domServCloudCacheStorageResourceIds = take(storageAccountResourceIds, 4)

// for EntraId we can only use 1 storage account per region so we must dedup by region keeping only the first storage account per region
// first get the reference to the storage accounts so we can create and array of objects containing the region and the storage account resource id
resource storageAccounts 'Microsoft.Storage/storageAccounts@2023-01-01' existing = [for id in storageAccountResourceIds: if(!contains(identitySolution, 'DomainServices')) {
  name: last(split(id, '/'))
  scope: resourceGroup(split(id, '/')[2], split(id, '/')[4])
}]

// then create an array of objects containing the region and the storage account resource id
module entraIdStorageAccounts 'filterUniqueRegion.bicep' = if(!contains(identitySolution, 'DomainServices')){
  name: 'aadVhdStorageAccounts'
  params: {
    storageAccounts: [for i in range(0,length(storageAccountResourceIds)): {
      location: storageAccounts[i].location
      id: storageAccounts[i].id
    }]
  }
}

// then limit the EntraId storage account resource ids to 4 total for scenario 3 and 4.
var entraIdStorageAccountResourceIds = take(entraIdStorageAccounts.outputs.storageAccountIds, 4)

output storageAccountResourceIds array = contains(identitySolution, 'DomainServices') ? ( contains(fslogixContainerType, 'CloudCache') ? domServCloudCacheStorageResourceIds : storageAccountResourceIds ) : entraIdStorageAccountResourceIds
