param adminGroups array = []
@secure()
param domainJoinUserPrincipalName string
@secure()
param domainJoinUserPassword string
param location string
param netAppServers array = []
param shares array
param userGroups array = []
param virtualMachineName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: virtualMachineName
}

resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'Set-NTFS-Permissions'
  location: location
  parent: virtualMachine
  properties: {
    asyncExecution: false
    parameters: [
      {
        name: 'AdminGroupNames'
        value: string(adminGroups)
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
        name: 'UserGroupNames'
        value: string(userGroups)
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
      script: loadTextContent('../../../../../.common/scripts/Set-NtfsPermissionsNetApp.ps1')
    }
    timeoutInSeconds: 300
    treatFailureAsDeploymentFailure: true
  }
}
