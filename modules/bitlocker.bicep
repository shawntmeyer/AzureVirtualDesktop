param _artifactsLocation string
@secure()
param _artifactsLocationSasToken string
param KeyVaultName string
param Location string
//param ManagedIdentityName string
param ManagedIdentityPrincipalId string
param ManagedIdentityResourceId string
param NamingStandard string
param ResourceGroupManagement string
param Timestamp string


/* resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, ManagedIdentityName, 'Contributor')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: ManagedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
} */

resource vault 'Microsoft.KeyVault/vaults@2016-10-01' = {
  name: KeyVaultName
  location: Location
  tags: {}
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: ManagedIdentityPrincipalId
        permissions: {
          keys: [
            'get'
            'list'
            'create'
          ]
          secrets: []
        }
      }
    ]
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: true
  }
}

module deploymentScript 'deploymentScript.bicep' = {
  name: 'DeploymentScript_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    Arguments: '-KeyVault ${KeyVaultName}'
    Location: Location
    Name: 'ds-${NamingStandard}-bitlockerKek'
    ScriptContainerSasToken: _artifactsLocationSasToken
    ScriptContainerUri: _artifactsLocation
    ScriptName: 'New-AzureKeyEncryptionKey.ps1'
    Timestamp: Timestamp
    UserAssignedIdentityResourceId: ManagedIdentityResourceId
  }
/* dependsOn: [
    roleAssignment
  ] */
}