param location string
param managementVmName string
param timeStamp string
param userAssignedIdentityClientId string
param virtualMachinesResourceGroup string
param virtualMachineNames array

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource removeRoleAssignments 'Microsoft.Compute/virtualMachines/runCommands@2023-09-01' = {
  parent: virtualMachine
  name: 'Remove-Role-Assignments-${timeStamp}'
  location: location
  properties: {    
    asyncExecution: true
    parameters: [      
      {
        name: 'ResourceManagerUri'
        value: environment().resourceManager
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
        name: 'VirtualMachineNames'
        value: string(virtualMachineNames)
      }
      {
        name: 'virtualMachinesResourceGroup'
        value: virtualMachinesResourceGroup
      }
    ]
    source: {
      script: loadTextContent('../../../../../.common/scripts/Remove-RunCommands.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
}
