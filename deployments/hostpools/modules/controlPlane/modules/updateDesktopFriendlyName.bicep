param applicationGroupResourceId string
param desktopFriendlyName string
param location string
param timeStamp string
param userAssignedIdentityClientId string
param virtualMachineName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: virtualMachineName
}

resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'updateDesktopFriendlyName_${timeStamp}'
  location: location
  parent: virtualMachine
  properties: {
    asyncExecution: false
    parameters: [
      {
        name: 'ApplicationGroupResourceId'
        value: applicationGroupResourceId
      }
      {
        name: 'FriendlyName'
        value: desktopFriendlyName
      }
      {
        name: 'ResourceManagerUri'
        value: environment().resourceManager
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
    ]
    source: {
      script: loadTextContent('../../../../../.common/scripts/Update-AvdSessionDesktopName.ps1')
    }
    timeoutInSeconds: 120
    treatFailureAsDeploymentFailure: true
  }
}
