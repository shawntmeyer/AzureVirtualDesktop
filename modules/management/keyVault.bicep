param DiskEncryptionOptions object
param DiskEncryptionKeyExpirationInDays int = 30
param DiskEncryptionSetName string
param DomainJoinUserPrincipalName string
@secure()
param DomainJoinUserPassword string
param Environment string
param KeyVaultName string
param Location string
param TagsDiskEncryptionSet object
param TagsKeyVault object
param Timestamp string
param VirtualMachineAdminUserName string
@secure()
param VirtualMachineAdminPassword string

resource vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: KeyVaultName
  location: Location
  tags: TagsKeyVault
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: Environment == 'd' || Environment == 't' ? 7 : 90
    tenantId: subscription().tenantId
  }
}

resource key 'Microsoft.KeyVault/vaults/keys@2022-07-01' = if(DiskEncryptionOptions.KeyEncryptionKey || DiskEncryptionOptions.DiskEncryptionSet) {
  parent: vault
  name: DiskEncryptionOptions.DiskEncryptionSet ? 'DiskEncryptionKey' : 'ADEKeyEncryptionKey'
  properties: {
    attributes: {
      enabled: true
    }
    keySize: 4096
    kty: 'RSA'
    rotationPolicy: {
      attributes: {
        expiryTime: 'P${string(DiskEncryptionKeyExpirationInDays)}D'
      }
      lifetimeActions: [
        {
          action: {
            type: 'Notify'
          }
          trigger: {
            timeBeforeExpiry: 'P10D'
          }
        }
        {
          action: {
            type: 'Rotate'
          }
          trigger: {
            timeAfterCreate: 'P${string(DiskEncryptionKeyExpirationInDays - 7)}D'
          }
        }
      ]
    }
  }
}

resource diskEncryptionSet 'Microsoft.Compute/diskEncryptionSets@2022-07-02' = if(DiskEncryptionOptions.DiskEncryptionSet) {
  name: DiskEncryptionSetName
  location: Location
  tags: TagsDiskEncryptionSet
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    activeKey: {
      sourceVault: {
        id: vault.id
      }
      keyUrl: key.properties.keyUriWithVersion
    }
    encryptionType: 'EncryptionAtRestWithPlatformAndCustomerKeys'
    rotationToLatestKeyVersionEnabled: true
  }
}

module roleAssignment '../roleAssignment.bicep' = if(DiskEncryptionOptions.DiskEncryptionSet) {
  name: 'RoleAssignment_${Timestamp}'
  params: {
    PrincipalId: diskEncryptionSet.identity.principalId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

resource secretDomainJoinUPN 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if(!empty(DomainJoinUserPrincipalName)) {
  parent: vault
  name: 'DomainJoinUserPrincipalName'
  properties: {
    contentType: 'text/plain'
    value: DomainJoinUserPrincipalName
  }
}

resource secretDomainJoinUserPassword 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if(!empty(DomainJoinUserPassword)) {
  parent: vault
  name: 'DomainJoinUserPassword'
  properties: {
    contentType: 'text/plain'
    value: DomainJoinUserPassword
  }
}

resource secretVirtualMachineAdminUserName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if(!empty(VirtualMachineAdminUserName)) {
  parent: vault
  name: 'VirtualMachineAdminUserName'
  properties: {
    contentType: 'text/plain'
    value: VirtualMachineAdminUserName
  }
}

resource secretVirtualMachineAdminPassword 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if(!empty(VirtualMachineAdminPassword)) {
  parent: vault
  name: 'VirtualMachineAdminPassword'
  properties: {
    contentType: 'text/plain'
    value: VirtualMachineAdminPassword
  }
}

output diskEncryptionSetResourceId string = DiskEncryptionOptions.DiskEncryptionSet ? diskEncryptionSet.id : ''
output keyVaultResourceId string = vault.id
output keyVaultUrl string = vault.properties.vaultUri
output keyId string = DiskEncryptionOptions.DiskEncryptionSet || DiskEncryptionOptions.KeyEncryptionKey ? key.id : ''
output keyUrl string = DiskEncryptionOptions.KeyEncryptionKey ? key.properties.keyUri : ''
