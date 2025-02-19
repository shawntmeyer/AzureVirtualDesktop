param existingWorkspaceResourceId string
param virtualMachineName string
param location string
param applicationGroupResourceId string
param timeStamp string
param userAssignedIdentityClientId string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: virtualMachineName
}

resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'addWorkspaceApplicationGroupReference_${timeStamp}'
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
        name: 'ResourceManagerUri'
        value: environment().resourceManager
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'WorkspaceResourceId'
        value: existingWorkspaceResourceId
      }
    ]
    source: {
      script: loadTextContent('../../../../../.common/scripts/Update-AvdWorkspaceAppReferences.ps1')
    }
    timeoutInSeconds: 180
    treatFailureAsDeploymentFailure: true
  }
}
