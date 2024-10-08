param location string
param timeStamp string
param userAssignedIdentityClientId string
param managementVmName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource deleteResourceGroup 'Microsoft.Compute/virtualMachines/runCommands@2023-09-01' = {
  parent: virtualMachine
  name: 'Delete-Management-ResourceGroup-${timeStamp}'
  location: location
  properties: {    
    asyncExecution: true
    parameters: [
      {
        name: 'ManagementResourceGroupResourceId'
        value: resourceGroup().id
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
      script: loadTextContent('../../../../../.common/scripts/Remove-ManagementResourceGroup.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
}
