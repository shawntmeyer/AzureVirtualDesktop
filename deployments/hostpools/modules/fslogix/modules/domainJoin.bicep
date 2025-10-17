@secure()
param domainJoinUserPrincipalName string
@secure()
param domainJoinUserPassword string
param hostPoolName string
param kerberosEncryptionType string = ''
param location string
param ouPath string = ''
param resourceGroupStorage string = ''
param storageAccountNamePrefix string = ''
param storageCount int = 0
param storageIndex int = 0
param userAssignedIdentityClientId string = ''
param virtualMachineName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: virtualMachineName
}

resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'Domain-Join'
  location: location
  parent: virtualMachine
  properties: {
    asyncExecution: false
    parameters: [
      {
        name: 'HostPoolName'
        value: hostPoolName
      }
      {
        name: 'KerberosEncryptionType'
        value: kerberosEncryptionType
      }
      {
        name: 'OuPath'
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
        name: 'StorageSuffix'
        value: environment().suffixes.storage
      }
      {
        name: 'SubscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
    ]
    protectedParameters: [
      {
        name: 'DomainJoinUserPrincipalName'
        value: domainJoinUserPrincipalName
      }
      {
        name: 'DomainJoinUserPwd'
        value: domainJoinUserPassword
      }
    ]
    source: {
      script: loadTextContent('../../../../../.common/scripts/Configure-StorageAccountforADDS.ps1')
    }
    timeoutInSeconds: 300
    treatFailureAsDeploymentFailure: true
  }
}
