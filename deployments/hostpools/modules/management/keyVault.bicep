@secure()
param domainJoinUserPrincipalName string = ''
@secure()
param domainJoinUserPassword string = ''
param enabledForDeployment bool = false
param enabledForDiskEncryption bool = false
param enabledForTemplateDeployment bool = false
param enablePurgeProtection bool = false
param envShortName string
param keyVaultName string
param keyVaultPrivateDnsZoneResourceId string
param location string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetId string
param skuName string
param tagsKeyVault object
param tagsPrivateEndpoints object
@secure()
param virtualMachineAdminUserName string = ''
@secure()
param virtualMachineAdminPassword string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: tagsKeyVault
  properties: {
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enablePurgeProtection: enablePurgeProtection ? enablePurgeProtection : null
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
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

resource vaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = if(privateEndpoint) { 
  name: replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', keyVaultName), 'VNETID', '${split(privateEndpointSubnetId, '/')[8]}')
  location: location
  tags: tagsPrivateEndpoints
  properties: {
    customNetworkInterfaceName: replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'vault'), 'RESOURCE', keyVaultName), 'VNETID', '${split(privateEndpointSubnetId, '/')[8]}')
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${keyVaultName}_${guid(keyVaultName)}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-08-01' = if (privateEndpoint && !empty(keyVaultPrivateDnsZoneResourceId)) {
  parent: vaultPrivateEndpoint
  name: keyVaultName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'ipconfig1'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZoneResourceId
        }
      }
    ]
  }
}

resource secretDomainJoinUPN 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if(!empty(domainJoinUserPrincipalName)) {
  parent: keyVault
  name: 'domainJoinUserPrincipalName'
  properties: {
    contentType: 'text/plain'
    value: domainJoinUserPrincipalName
  }
}

resource secretdomainJoinUserPassword 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if(!empty(domainJoinUserPassword)) {
  parent: keyVault
  name: 'domainJoinUserPassword'
  properties: {
    contentType: 'text/plain'
    value: domainJoinUserPassword
  }
}

resource secretVirtualMachineAdminUserName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if(!empty(virtualMachineAdminUserName)) {
  parent: keyVault
  name: 'virtualMachineAdminUserName'
  properties: {
    contentType: 'text/plain'
    value: virtualMachineAdminUserName
  }
}

resource secretVirtualMachineAdminPassword 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if(!empty(virtualMachineAdminPassword)) {
  parent: keyVault
  name: 'virtualMachineAdminPassword'
  properties: {
    contentType: 'text/plain'
    value: virtualMachineAdminPassword
  }
}

output keyVaultResourceId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
