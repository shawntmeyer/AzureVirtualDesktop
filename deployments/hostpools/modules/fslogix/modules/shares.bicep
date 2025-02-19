param fileShares array
param shareSizeInGB int
param StorageAccountName string
param storageSku string

resource shares 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = [for i in range(0, length(fileShares)): {
  name: '${StorageAccountName}/default/${fileShares[i]}'
  properties: {
    accessTier: storageSku == 'Premium' ? 'Premium' : 'TransactionOptimized'
    shareQuota: shareSizeInGB
    enabledProtocols: 'SMB'
  }
}]
