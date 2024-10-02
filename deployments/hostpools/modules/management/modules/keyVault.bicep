param enabledForDiskEncryption bool = false
param enablePurgeProtection bool = false
param envShortName string
param keyVaultName string
param keyVaultPrivateDnsZoneResourceId string
param location string
param privateEndpoint bool
param privateEndpointLocation string
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param skuName string
param tags object
param timeStamp string

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: tags[?'Microsoft.KeyVault/vaults'] ?? {}
  properties: {
    enabledForDiskEncryption: enabledForDiskEncryption
    enablePurgeProtection: enablePurgeProtection ? enablePurgeProtection : null
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: privateEndpoint ? 'Deny' : 'Allow'
    }
    publicNetworkAccess: privateEndpoint ? 'Disabled' : 'Enabled'
    sku: {
      family: 'A'
      name: skuName
    }
    softDeleteRetentionInDays: envShortName == 'd' || envShortName == 't' ? 7 : 90
    tenantId: subscription().tenantId
  }
}

module vault_privateEndpoint '../../../../sharedModules/resources/network/private-endpoint/main.bicep' = if(privateEndpoint && !empty(privateEndpointSubnetResourceId) && !empty(keyVaultPrivateDnsZoneResourceId)) {
  name: '${keyVaultName}_privateEndpoint_${timeStamp}'
  params: {
    customNetworkInterfaceName: replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', keyVaultName), 'VNETID', '${split(privateEndpointSubnetResourceId, '/')[8]}')
    groupIds: [
      'vault'
    ]
    location: privateEndpointLocation
    name: replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', keyVaultName), 'VNETID', '${split(privateEndpointSubnetResourceId, '/')[8]}')
    privateDnsZoneGroup: {
      privateDNSResourceIds: [
        keyVaultPrivateDnsZoneResourceId
      ]
    }
    serviceResourceId: keyVault.id
    subnetResourceId: privateEndpointSubnetResourceId
    tags: tags[?'Microsoft.Network/privateEndpoints'] ?? {}
  }
}

output keyVaultResourceId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
