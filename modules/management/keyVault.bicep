@secure()
param domainJoinUserPrincipalName string
@secure()
param domainJoinUserPassword string
param environmentShortName string
param keyVaultName string
param keyVaultPrivateDnsZoneResourceId string
param location string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointSubnetId string
param tagsKeyVault object
param tagsPrivateEndpoints object
param virtualMachineAdminUserName string
@secure()
param virtualMachineAdminPassword string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  tags: tagsKeyVault
  properties: {
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: environmentShortName == 'd' || environmentShortName == 't' ? 7 : 90
    tenantId: subscription().tenantId
  }
}

resource vaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-05-01' = {
  name: replace(replace(privateEndpointNameConv, 'subresource', 'vault'), 'resource', keyVaultName)
  location: location
  tags: tagsPrivateEndpoints
  properties: {
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
output keyVaultUrl string = keyVault.properties.vaultUri
