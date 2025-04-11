param confidentialVMOSDiskEncryption bool
param confidentialVMOrchestratorObjectId string
param deploymentUserAssignedIdentityClientId string
param diskEncryptionSetNames object
param hostPoolResourceId string
param keyExpirationInDays int = 180
param keyManagementDisks string
param keyVaultName string
param deploymentVirtualMachineName string
param resourceGroupDeployment string
param resourceGroupManagement string
param tags object
param timeStamp string

var confidentialVMEncryptionKeyName = 'ConfidentialVMOSDiskEncryptionKey'
var vmEncryptionKeyName = 'VMOSDiskEncryptionKey'
var diskEncryptionSetEncryptionType = confidentialVMOSDiskEncryption
  ? 'ConfidentialVmEncryptedWithCustomerKey'
  : (!contains(keyManagementDisks, 'Platform')
      ? 'EncryptionAtRestWithCustomerKey'
      : 'EncryptionAtRestWithPlatformAndCustomerKeys')

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = if(!confidentialVMOSDiskEncryption) {
  name: keyVaultName
  scope: resourceGroup(resourceGroupManagement)
}

module keys '../../../../sharedModules/resources/key-vault/vault/key/main.bicep' = if(!confidentialVMOSDiskEncryption) {
  name: 'Encryption_Key_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    attributesEnabled: true
    attributesExportable: false
    keySize: 4096
    keyVaultName: keyVaultName
    kty: contains(keyManagementDisks, 'HSM') ? 'RSA-HSM' : 'RSA'
    name: vmEncryptionKeyName
    rotationPolicy: {
      attributes: {
        expiryTime: 'P${string(keyExpirationInDays)}D'
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
            timeAfterCreate: 'P${string(keyExpirationInDays - 7)}D'
          }
        }
      ]
    }
    tags: {'cm-resource-parent': hostPoolResourceId}
  }
}

module set_confidentialVM_key_disks '../../../../sharedModules/resources/compute/virtual-machine/runCommand/main.bicep' = if(confidentialVMOSDiskEncryption) {
  name: 'Set_EncryptionKey_ConfidentialVMOSDisk_${timeStamp}'
  scope: resourceGroup(resourceGroupDeployment)
  params: {
    name: 'Set_confidentialVM_key_disks'
    parameters: [
      {
        name: 'KeyName'
        value: confidentialVMEncryptionKeyName
      }
      {
        name: 'Tags'
        value: string(tags[?'Microsoft.KeyVault/vaults/keys'] ?? {})
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: deploymentUserAssignedIdentityClientId
      }
      {
        name: 'VaultUri'
        value: keyVault.properties.vaultUri
      }
    ]
    script: loadTextContent('../../../../../.common/scripts/Set-ConfidentialVMOSDiskEncryptionKey.ps1')
    treatFailureAsDeploymentFailure: true
    virtualMachineName: deploymentVirtualMachineName  
  }
}

module roleAssignment_ConfVMOrchestrator_EncryptUser '../../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = if (confidentialVMOSDiskEncryption) {
  name: 'RoleAssignment_ConfVMOrchestrator_EncryptUser_${timeStamp}'
  params: {
    principalId: confidentialVMOrchestratorObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

module roleAssignment_ConfVMOrchestrator_ReleaseUser '../../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = if (confidentialVMOSDiskEncryption) {
  name: 'RoleAssignment_ConfVMOrchestrator_ReleaseUser_${timeStamp}'
  params: {
    principalId: confidentialVMOrchestratorObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '08bbd89e-9f13-488c-ac41-acfcb10c90ab' // Key Vault Crypto Service Release User
  }
}

module diskEncryptionSet '../../../../sharedModules/resources/compute/disk-encryption-set/main.bicep' = {
  name: 'DiskEncryptionSet_${timeStamp}'
  params: {
    rotationToLatestKeyVersionEnabled: confidentialVMOSDiskEncryption ? false : true
    name: confidentialVMOSDiskEncryption ? diskEncryptionSetNames.ConfidentialVMs : (diskEncryptionSetEncryptionType == 'EncryptionAtRestWithCustomerKey' ? diskEncryptionSetNames.CustomerManaged : diskEncryptionSetNames.PlatformAndCustomerManaged)
    encryptionType: diskEncryptionSetEncryptionType
    keyName: confidentialVMOSDiskEncryption ? confidentialVMEncryptionKeyName : vmEncryptionKeyName
    keyVaultResourceId: keyVault.id
    systemAssignedIdentity: true
    tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.Compute/diskEncryptionSets'] ?? {})
  }
}

module roleAssignment_DiskEncryptionSet_EncryptUser '../../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = {
  name: 'RoleAssignment_DiskEncryptionSet_EncryptUser_${timeStamp}'
  params: {
    principalId: diskEncryptionSet.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

output diskEncryptionSetResourceId string = diskEncryptionSet.outputs.resourceId
output diskEncryptionSetRoleAssignmentId string = roleAssignment_DiskEncryptionSet_EncryptUser.outputs.resourceId
