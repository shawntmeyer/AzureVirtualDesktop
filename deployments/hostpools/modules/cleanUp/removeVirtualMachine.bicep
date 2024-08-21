param location string
param userAssignedIdentityClientId string
param virtualMachineName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: virtualMachineName
}

resource removeVirtualMachine 'Microsoft.Compute/virtualMachines/runCommands@2023-09-01' = {
  parent: virtualMachine
  name: 'RemoveManagementVM'
  location: location
  properties: {    
    asyncExecution: true
    parameters: [
      {
        name: 'ManagementVmResourceId'
        value: virtualMachine.id
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
      script: loadTextContent('../../../../.common/scripts/Remove-ManagementVM.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
}
