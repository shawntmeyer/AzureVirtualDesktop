param azureKeyVaultPrivateDnsZoneResourceId string
param fslogixStorageAccountEncryptionKeysVaultNameConv string
param hostPoolResourceId string
param keyManagementStorageAccounts string
param keyExpirationInDays int = 180
param location string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param storageAccountNamePrefix string
param storageCount int
param storageIndex int
param storageSolution string
param tags object
param timeStamp string
param userAssignedIdentityNameConv string

var storageAccountEncryptionKeyName = 'StorageAccountEncryptionKey'

module storageAccountKeyVaults '../../../../sharedModules/resources/key-vault/vault/main.bicep' = [for i in range(0, storageCount): {
  name: 'KeyVault_${replace(fslogixStorageAccountEncryptionKeysVaultNameConv, 'STORAGEACCOUNTNAME', '${storageAccountNamePrefix}${string(padLeft(i + storageIndex, 2, '0'))}')}_${timeStamp}'
  params: {
    location: location
    name: replace(fslogixStorageAccountEncryptionKeysVaultNameConv, 'STORAGEACCOUNTNAME', '${storageAccountNamePrefix}${string(padLeft(i + storageIndex, 2, '0'))}')
    enablePurgeProtection: true
    enableSoftDelete: true
    enableVaultForDiskEncryption: false
    keys:[
      {
        attributesExportable: false
        name: storageAccountEncryptionKeyName
        keySize: 4096
        kty: contains(keyManagementStorageAccounts, 'HSM') ? 'RSA-HSM' : 'RSA'
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
        tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.KeyVault/vaults/keys'] ?? {})
      }
    ]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: privateEndpoint ? 'Deny' : 'Allow'
    }
    privateEndpoints: privateEndpoint && !empty(privateEndpointSubnetResourceId) && !empty(azureKeyVaultPrivateDnsZoneResourceId)
      ? [
          {
            customNetworkInterfaceName: replace(
              replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', replace(fslogixStorageAccountEncryptionKeysVaultNameConv, 'STORAGEACCOUNTNAME', '${storageAccountNamePrefix}${string(padLeft(i + storageIndex, 2, '0'))}')),
              'VNETID',
              '${split(privateEndpointSubnetResourceId, '/')[8]}'
            )
            name: replace(
              replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', replace(fslogixStorageAccountEncryptionKeysVaultNameConv, 'STORAGEACCOUNTNAME', '${storageAccountNamePrefix}${string(padLeft(i + storageIndex, 2, '0'))}')),
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
            tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.Network/privateEndpoints'] ?? {})
          }
        ]
      : null      
    tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.KeyVault/vaults'] ?? {})
    vaultSku: contains(keyManagementStorageAccounts, 'HSM') ? 'premium' : 'standard'
  }
}]

module userAssignedIdentity '../../../../sharedModules/resources/managed-identity/user-assigned-identity/main.bicep' = {
  name: 'UAI_Encryption_${timeStamp}'
  params: {
    location: location
    name: replace(userAssignedIdentityNameConv, 'TOKEN', 'storage-encryption')
    tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.ManagedIdentity/userAssignedIdentities'] ?? {})
  }
}

module roleAssignment_UAI_EncryptUser '../../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = {
  name: 'RoleAssignment_Encryption_UAI_EncryptUser_${timeStamp}'
  params: {
    principalId: userAssignedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

output keyVaultUris array = [for i in range(0, storageCount): storageAccountKeyVaults[i].outputs.uri]
output storageEncryptionKeyName string = storageAccountEncryptionKeyName
// temp to avoid error
output storageSolution string = storageSolution
output userAssignedIdentityResourceId string = userAssignedIdentity.outputs.resourceId