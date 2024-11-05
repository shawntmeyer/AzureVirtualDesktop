param confidentialVMOSDiskEncryption bool
param confidentialVMOrchestratorObjectId string
param deploymentUserAssignedIdentityClientId string
param diskEncryptionSetNames object
param diskEncryptionKeyExpirationInDays int = 180
param hostPoolResourceId string
param keyManagementDisks string
param keyVaultNames object
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
    enableVaultForDiskEncryption: true
    enablePurgeProtection: true
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
            expiryTime: 'P${string(diskEncryptionKeyExpirationInDays)}D'
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
                timeAfterCreate: 'P${string(diskEncryptionKeyExpirationInDays - 7)}D'
              }
            }
          ]
        }
        tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.KeyVault/vaults/keys'] ?? {})
      }
    ]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: privateEndpoint ? 'Deny' : 'Allow'
    }
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
            privateDnsZoneGroup: {
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
    tags: union({'cm-resource-parent':hostPoolResourceId}, tags[?'Microsoft.KeyVault/vaults'] ?? {})
    vaultSku: confidentialVMOSDiskEncryption || contains(keyManagementDisks, 'HSM') ? 'premium' : 'standard'
    enableRbacAuthorization: true
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

/*
module userAssignedIdentity '../../../../sharedModules/resources/managed-identity/user-assigned-identity/main.bicep' = {
  name: 'UAI_Encryption_${timeStamp}'
  params: {
    location: location
    name: replace(userAssignedIdentityNameConv, 'TOKEN', 'os-disk-encryption')
    tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.ManagedIdentity/userAssignedIdentities'] ?? {})
  }
}
*/

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