param location string
param timeStamp string
param userAssignedIdentityClientId string
param managementVmName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource removeVirtualMachine 'Microsoft.Compute/virtualMachines/runCommands@2023-09-01' = {
  parent: virtualMachine
  name: 'Remove-ManagementVM-${timeStamp}'
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
      script: loadTextContent('../../../../../.common/scripts/Remove-ManagementVM.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
}
