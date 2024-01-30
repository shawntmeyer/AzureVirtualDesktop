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

module roleAssignment '../common/roleAssignment.bicep' = {
  name: 'RoleAssignment_Encryption_${timeStamp}'
  params: {
    PrincipalId: diskEncryptionSet.identity.principalId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

output resourceId string = diskEncryptionSet.id
