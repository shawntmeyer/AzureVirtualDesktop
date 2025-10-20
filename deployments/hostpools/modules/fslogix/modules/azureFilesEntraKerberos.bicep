param storageAccountName string
param kind string
param sku object
param location string
param domainGuid string
param domainName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  properties: {
    azureFilesIdentityBasedAuthentication: {   
      activeDirectoryProperties: !empty(domainGuid) && !empty(domainGuid) ? {
        domainGuid: domainGuid
        domainName: domainName
      } : null
      defaultSharePermission: 'None'   
      directoryServiceOptions: 'AADKERB'
    }
  }
  kind: kind
  location: location
  sku: sku
}
