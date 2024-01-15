param fileShares array
param location string
param PolicyId string
param ProtectionContainerName string
param SourceResourceId string
param tags object

// Only configures backups for profile containers
// Office containers contain M365 cached data that does not need to be backed up
resource protectedItems_FileShare 'Microsoft.recoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2022-03-01' = [for FileShare in fileShares: if (contains(FileShare, 'profile')) {
  name: '${ProtectionContainerName}/AzureFileShare;${FileShare}'
  location: location
  tags: tags
  properties: {
    protectedItemType: 'AzureFileShareProtectedItem'
    policyId: PolicyId
    sourceResourceId: SourceResourceId
  }
}]
