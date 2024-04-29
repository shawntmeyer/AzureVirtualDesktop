param cloud string
param location string = resourceGroup().location
param imageVmName string
param managementVmName string
param imageResourceId string
param userAssignedIdentityClientId string

resource managementVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource removeVm 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'removeVm'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: true
    parameters: [
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ResourceGroupName'
        value: split(managementVm.id, '/')[4]
      }
      {
        name: 'imageVmName'
        value: imageVmName
      }
      {
        name: 'managementVmName'
        value: managementVmName
      }
      {
        name: 'imageName'
        value: last(split(imageResourceId, '/'))
      }
      {
        name: 'Environment'
        value: cloud
      }
    ]
    source: {
      script: '''
        param(
          [string]$Environment,
          [string]$UserAssignedIdentityClientId,
          [string]$imageName,
          [string]$imageVmName,
          [string]$managementVmName,
          [string]$ResourceGroupName
        )
        # Connect to Azure
        Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -Environment $Environment # Run on the virtual machine
        # Remove Image VM and Management VM
        If ($imageName -ne '') {
          Remove-AzImage -Name $imageName -ResourceGroupName $ResourceGroupName -Force
        }
        Remove-AzVM -Name $imageVmName -ResourceGroupName $ResourceGroupName -ForceDeletion $true -Force
        Remove-AzVM -Name $managementVmName -ResourceGroupName $ResourceGroupName -NoWait -ForceDeletion $true -Force -AsJob
      '''
    }
  }
}
