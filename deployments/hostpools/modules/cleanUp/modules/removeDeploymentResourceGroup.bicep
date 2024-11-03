param location string
param timeStamp string
param userAssignedIdentityClientId string
param deploymentVmName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: deploymentVmName
}

resource deleteResourceGroup 'Microsoft.Compute/virtualMachines/runCommands@2023-09-01' = {
  parent: virtualMachine
  name: 'Delete_DeploymentResourceGroup_${timeStamp}'
  location: location
  properties: {    
    asyncExecution: true
    parameters: [
      {
        name: 'ResourceGroupResourceId'
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
      script: loadTextContent('../../../../../.common/scripts/Remove-ResourceGroup.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
}
