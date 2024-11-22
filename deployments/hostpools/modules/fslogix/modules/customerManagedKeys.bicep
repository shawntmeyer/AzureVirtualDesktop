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
param tags object
param timeStamp string
param userAssignedIdentityNameConv string

var storageAccountEncryptionKeyName = 'StorageAccountEncryptionKey'

resource keyVaults 'Microsoft.KeyVault/vaults@2023-07-01' = [for i in range(0, storageCount): {
  name: replace(fslogixStorageAccountEncryptionKeysVaultNameConv, 'STORAGEACCOUNTNAME', '${storageAccountNamePrefix}${string(padLeft(i + storageIndex, 2, '0'))}')
  location: location
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    sku: {
      family: 'A'
      name: contains(keyManagementStorageAccounts, 'HSM') ? 'premium' : 'standard'
    }
    publicNetworkAccess: privateEndpoint ? 'Disabled' : 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: privateEndpoint ? 'Deny' : 'Allow'
    }
    softDeleteRetentionInDays: 90    
    tenantId: subscription().tenantId
  }
  tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.KeyVault/vaults'] ?? {})
}]

resource storageAccountEncryptionKeys 'Microsoft.KeyVault/vaults/keys@2023-07-01' = [for i in range(0, storageCount): {
  parent: keyVaults[i]
  name: storageAccountEncryptionKeyName
  properties: {
    attributes: {
      enabled: true
    }
    keySize: 4096
    kty: contains(keyManagementStorageAccounts, 'HSM') ? 'RSA-HSM' : 'RSA'
    rotationPolicy: {
      attributes: {
        expiryTime: 'P${string(keyExpirationInDays)}D'
      }
      lifetimeActions: [
        {
          action: {
            type: 'notify'
          }
          trigger: {
            timeBeforeExpiry: 'P10D'
          }
        }
        {
          action: {
            type: 'rotate'
          }
          trigger: {
            timeAfterCreate: 'P${string(keyExpirationInDays - 7)}D'
          }
        }
      ]
    }
  }
}]

resource keyVault_privateEndpoints 'Microsoft.Network/privateEndpoints@2023-04-01' = [for i in range(0, storageCount): if(privateEndpoint && !empty(privateEndpointSubnetResourceId)) {
  name: replace(
    replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', replace(fslogixStorageAccountEncryptionKeysVaultNameConv, 'STORAGEACCOUNTNAME', '${storageAccountNamePrefix}${string(padLeft(i + storageIndex, 2, '0'))}')),
    'VNETID',
    '${split(privateEndpointSubnetResourceId, '/')[8]}'
  )
  location: location
  properties: {
    customNetworkInterfaceName: replace(
      replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', replace(fslogixStorageAccountEncryptionKeysVaultNameConv, 'STORAGEACCOUNTNAME', '${storageAccountNamePrefix}${string(padLeft(i + storageIndex, 2, '0'))}')),
      'VNETID',
      '${split(privateEndpointSubnetResourceId, '/')[8]}'
    )
    privateLinkServiceConnections: [
      {
        name: replace(
          replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', replace(fslogixStorageAccountEncryptionKeysVaultNameConv, 'STORAGEACCOUNTNAME', '${storageAccountNamePrefix}${string(padLeft(i + storageIndex, 2, '0'))}')),
          'VNETID',
          '${split(privateEndpointSubnetResourceId, '/')[8]}'
        )
        properties: {
          groupIds: [
            'vault'
          ]
          privateLinkServiceId: keyVaults[i].id
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetResourceId
    }
  }
  dependsOn: [
    storageAccountEncryptionKeys[i]
  ]  
}]

resource keyVault_privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = [for i in range(0, storageCount): if(privateEndpoint && !empty(privateEndpointSubnetResourceId) && !empty(azureKeyVaultPrivateDnsZoneResourceId)) {
  parent : keyVault_privateEndpoints[i]
  name: keyVaults[i].name
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'ipconfig1'
        properties : {
          privateDnsZoneId: azureKeyVaultPrivateDnsZoneResourceId
        }
      }
    ]
  }
}]

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: replace(userAssignedIdentityNameConv, 'TOKEN', 'storage-encryption')
  location: location
  tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.ManagedIdentity/userAssignedIdentities'] ?? {})
}

module roleAssignment_UAI_EncryptUser '../../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = {
  name: 'RoleAssignment_Encryption_UAI_EncryptUser_${timeStamp}'
  params: {
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: 'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  }
}

output keyVaultUris array = [for i in range(0, storageCount): keyVaults[i].properties.vaultUri]
output storageEncryptionKeyName string = storageAccountEncryptionKeyName
output userAssignedIdentityResourceId string = userAssignedIdentity.id
