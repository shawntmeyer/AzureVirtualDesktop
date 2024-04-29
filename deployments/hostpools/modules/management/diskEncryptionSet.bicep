param autoKeyRotationEnabled bool
param diskEncryptionSetName string
param encryptionType string
param keyVaultResourceId string
param keyUrl string

param location string
param tags object
param timeStamp string

resource diskEncryptionSet 'Microsoft.Compute/diskEncryptionSets@2022-07-02' = {
  name: diskEncryptionSetName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'

  }
  properties: {
    activeKey: {
      sourceVault: {
        id: keyVaultResourceId
      }
      keyUrl: keyUrl
    }
    encryptionType: encryptionType
    rotationToLatestKeyVersionEnabled: autoKeyRotationEnabled
  }
}

module roleAssignment '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = {
  name: 'RoleAssignment_Encryption_${timeStamp}'
  params: {
    principalId: diskEncryptionSet.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

output resourceId string = diskEncryptionSet.id
