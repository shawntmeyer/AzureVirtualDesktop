param adminGroupNames array = []
param shares array
@secure()
param domainJoinUserPrincipalName string
@secure()
param domainJoinUserPassword string
param kerberosEncryptionType string = ''
param location string
param netAppServers array = []
param ouPath string = ''
param resourceGroupStorage string = ''
param shardingOptions string
param storageAccountNamePrefix string = ''
param storageCount int = 0
param storageIndex int = 0
param storageSolution string
param timeStamp string
param userGroupNames array = []
param userAssignedIdentityClientId string = ''
param virtualMachineName string

var azureFilesParameters = [
  {
    name: 'AdminGroupNames'
    value: string(adminGroupNames)
  }
  {
    name: 'Shares'
    value: string(shares)
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
    name: 'ShardAzureFilesStorage'
    value: shardingOptions == 'None' ? 'true' : 'false'
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
  {
    name: 'SubscriptionId'
    value: subscription().subscriptionId
  }
  {
    name: 'UserAssignedIdentityClientId'
    value: userAssignedIdentityClientId
  }
  {
    name: 'UserGroupNames'
    value: string(userGroupNames)
  }
]

var azureNetAppParameters = [
  {
    name: 'AdminGroupNames'
    value: string(adminGroupNames)
  }
  {
    name: 'NetAppServers'
    value: string(netAppServers)
  }
  {
    name: 'Shares'
    value: string(shares)
  }
  {
    name: 'StorageSolution'
    value: storageSolution
  }
  {
    name: 'UserGroupNames'
    value: string(userGroupNames)
  }      
]

var runCommandName = storageSolution == 'AzureFiles' ? 'Domain_Join_Set_NTFSPermissions_${timeStamp}' : 'Set_NTFS_Permissions_${timeStamp}'

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: virtualMachineName
}

resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: runCommandName
  location: location
  parent: virtualMachine
  properties: {
    asyncExecution: false
    parameters: storageSolution == 'AzureFiles' ? azureFilesParameters : azureNetAppParameters
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
      script: loadTextContent('../../../../../.common/scripts/Set-NtfsPermissions.ps1')
    }
    timeoutInSeconds: 300
    treatFailureAsDeploymentFailure: true
  }
}
