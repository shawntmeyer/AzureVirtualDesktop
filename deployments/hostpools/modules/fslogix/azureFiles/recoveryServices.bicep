param fileShares array
param location string
param recoveryServicesVaultName string
param resourceGroupStorage string
param storageAccountNamePrefix string
param storageCount int
param storageIndex int
param tagsRecoveryServicesVault object
param timeStamp string

resource vault 'Microsoft.recoveryServices/vaults@2022-03-01' existing =  {
  name: recoveryServicesVaultName
}

resource protectionContainers 'Microsoft.recoveryServices/vaults/backupFabrics/protectionContainers@2022-03-01' = [for i in range(0, storageCount): {
  name: '${vault.name}/Azure/storagecontainer;Storage;${resourceGroupStorage};${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}'
  properties: {
    backupManagementType: 'AzureStorage'
    containerType: 'StorageContainer'
    sourceResourceId: resourceId(resourceGroupStorage, 'Microsoft.Storage/storageAccounts', '${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}')
  }
}]

resource backupPolicy_Storage 'Microsoft.recoveryServices/vaults/backupPolicies@2022-03-01' existing = {
  parent: vault
  name: 'AvdPolicyStorage'
}

module protectedItems_FileShares 'protectedItems.bicep' = [for i in range(0, storageCount): {
  name: 'BackupProtectedItems_FileShares_${i + storageIndex}_${timeStamp}'
  params: {
    fileShares: fileShares
    location: location
    ProtectionContainerName: protectionContainers[i].name
    PolicyId: backupPolicy_Storage.id
    SourceResourceId: resourceId(resourceGroupStorage, 'Microsoft.Storage/storageAccounts', '${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}')
    tags: tagsRecoveryServicesVault
  }
}]
