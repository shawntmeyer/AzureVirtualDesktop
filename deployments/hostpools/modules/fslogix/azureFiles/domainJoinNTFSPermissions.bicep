param adminGroupDomainNames array
param adminGroupSamAccountNames array
param deploymentUserAssignedIdentityClientId string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param fslogixContainerType string
param identitySolution string
param kerberosEncryption string
param location string
param netbios string
param ouPath string
param resourceGroupStorage string
param storageAccountNamePrefix string
param storageCount int
param storageIndex int
param storageSolution string
param virtualMachineName string

resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' existing = {
  name: virtualMachineName
}

resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2023-09-01' = {
  name: 'DomainJoinNtfsPermissions'
  parent: vm
  location: location
  properties: {
    parameters: [
      {
        name: 'AdminGroupDomainNames'
        value: string(adminGroupDomainNames)
      }
      {
        name: 'AdminGroupSamAccountNames'
        value: string(adminGroupSamAccountNames)
      }
      {
        name: 'ActiveDirectorySolution'
        value: identitySolution
      }
      {
        name: 'FSLogixContainerType'
        value: fslogixContainerType
      }
      {
        name: 'KerberosEncryptionType'
        value: kerberosEncryption
      }
      {
        name: 'Netbios'
        value: netbios
      }
      {
        name: 'OUPath'
        value: ouPath
      }
      {
        name: 'ResourceManagerUri'
        value: environment().resourceManager
      }
      {
        name: 'StorageAccountPrefix'
        value: storageAccountNamePrefix
      }
      {
        name: 'StorageAccountResourceGroupName'
        value: resourceGroupStorage
      }
      {
        name: 'StorageCount'
        value: string(storageCount)
      }
      {
        name: 'StorageIndex'
        value: string(storageIndex)
      }
      {
        name: 'StorageSolution'
        value: storageSolution
      }
      {
        name: 'StorageSuffix'
        value: environment().suffixes.storage
      }
      { name: 'SubscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: deploymentUserAssignedIdentityClientId
      }
    ]
    protectedParameters: [
      {
        name: 'DomainJoinUserPwd'
        value: domainJoinUserPassword
      }
      {
        name: 'DomainJoinUserPrincipalName'
        value: domainJoinUserPrincipalName
      }
    ]
    source: {
      script: loadTextContent('../../../../../.common/scripts/Set-NtfsPermissions.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
}
