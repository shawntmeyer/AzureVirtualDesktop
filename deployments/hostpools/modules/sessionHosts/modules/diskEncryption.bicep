param confidentialVMOSDiskEncryption bool
param confidentialVMOrchestratorObjectId string
param deploymentUserAssignedIdentityClientId string
param diskEncryptionSetNames object
param hostPoolResourceId string
param keyExpirationInDays int = 180
param keyManagementDisks string
param keyVaultNames object
param keyVaultRetentionInDays int
param azureKeyVaultPrivateDnsZoneResourceId string
param logAnalyticsWorkspaceResourceId string
param deploymentVirtualMachineName string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param resourceGroupDeployment string
param tags object
param timeStamp string

var confidentialVMEncryptionKeyName = 'ConfidentialVMOSDiskEncryptionKey'
var vmEncryptionKeyName = 'VMOSDiskEncryptionKey'
var diskEncryptionSetEncryptionType = confidentialVMOSDiskEncryption
  ? 'ConfidentialVmEncryptedWithCustomerKey'
  : (!contains(keyManagementDisks, 'Platform')
      ? 'EncryptionAtRestWithCustomerKey'
      : 'EncryptionAtRestWithPlatformAndCustomerKeys')

module KeyVault '../../../../sharedModules/resources/key-vault/vault/main.bicep' = {
  name: 'Encryption_KeyVault_${timeStamp}'
  params: {
    diagnosticWorkspaceId: logAnalyticsWorkspaceResourceId
    enableVaultForDeployment: false
    enableVaultForDiskEncryption: true
    enableVaultForTemplateDeployment: false
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    name: keyVaultNames.VMEncryptionKeys
    keys: confidentialVMOSDiskEncryption ? null : [
      {
        attributesEnabled: true
        attributesExportable: false
        name: vmEncryptionKeyName
        keySize: 4096
        kty: contains(keyManagementDisks, 'HSM') ? 'RSA-HSM' : 'RSA'
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
      }
    ]
    privateEndpoints: privateEndpoint && !empty(privateEndpointSubnetResourceId)
      ? [
          {
            customNetworkInterfaceName: replace(
              replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', keyVaultNames.VMEncryptionKeys),
              'VNETID',
              '${split(privateEndpointSubnetResourceId, '/')[8]}'
            )
            name: replace(
              replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', keyVaultNames.VMEncryptionKeys),
              'VNETID',
              '${split(privateEndpointSubnetResourceId, '/')[8]}'
            )
            privateDnsZoneGroup: empty(azureKeyVaultPrivateDnsZoneResourceId) ? null : {
              privateDNSResourceIds: [
                azureKeyVaultPrivateDnsZoneResourceId
              ]
            }
            service: 'vault'
            subnetResourceId: privateEndpointSubnetResourceId
            tags: tags[?'Microsoft.Network/privateEndpoints'] ?? {}
          }
        ]
      : null      
    softDeleteRetentionInDays: keyVaultRetentionInDays
    tags: union({'cm-resource-parent':hostPoolResourceId}, tags[?'Microsoft.KeyVault/vaults'] ?? {})
    vaultSku: confidentialVMOSDiskEncryption || contains(keyManagementDisks, 'HSM') ? 'premium' : 'standard'
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
        value: KeyVault.outputs.uri
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
    keyVaultResourceId: KeyVault.outputs.resourceId
    systemAssignedIdentity: true
    tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.Compute/diskEncryptionSets'] ?? {})
  }
}

module roleAssignment_DiskEncryptionSet_EncryptUser 'keyVault_RBAC.bicep' = {
  name: 'RoleAssignment_DiskEncryptionSet_EncryptUser_${timeStamp}'
  params: {
    principalId: diskEncryptionSet.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
    keyName: confidentialVMOSDiskEncryption ? confidentialVMEncryptionKeyName : vmEncryptionKeyName
    keyVaultName: KeyVault.outputs.name
  }
}

output diskEncryptionSetResourceId string = diskEncryptionSet.outputs.resourceId
