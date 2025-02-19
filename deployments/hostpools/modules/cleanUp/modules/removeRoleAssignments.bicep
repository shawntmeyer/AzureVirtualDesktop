param location string
param roleAssignmentIds array
param timeStamp string
param userAssignedIdentityClientId string
param managementVmName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource removeRoleAssignments 'Microsoft.Compute/virtualMachines/runCommands@2023-09-01' = {
  parent: virtualMachine
  name: 'Remove_RoleAssignments_${timeStamp}'
  location: location
  properties: {    
    asyncExecution: true
    parameters: [
      {
        name: 'ResourceManagerUri'
        value: environment().resourceManager
      }
      {
        name: 'RoleAssignmentIds'
        value: string(roleAssignmentIds)
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
    ]
    source: {
      script: loadTextContent('../../../../../.common/scripts/Remove-RoleAssignments.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
}
