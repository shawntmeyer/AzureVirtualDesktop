param cloud string
param location string = resourceGroup().location
param imageVmName string
param managementVmName string
param userAssignedIdentityClientId string

resource imageVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: imageVmName
}

resource managementVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource generalize 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'generalize'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: false
    parameters: [
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ImageVmRg'
        value: split(imageVm.id, '/')[4]
      }
      {
        name: 'ImageVmName'
        value: imageVmName
      }
      {
        name: 'Environment'
        value: cloud
      }
    ]
    source: {
      script: '''
      param(
        [string]$UserAssignedIdentityClientId,
        [string]$ImageVmRg,
        [string]$ImageVmName,
        [string]$Environment
        )
        # Connect to Azure
        Connect-AzAccount -Identity -AccountId $miClientId -Environment $Environment # Run on the virtual machine

        Do {
          Start-Sleep -seconds 5
        } Until (Get-AzResource -ResourceType 'Microsoft.Compute/VirtualMachines')
        
        # Generalize VM Using PowerShell
        Stop-AzVM -ResourceGroupName $imageVmRg -Name $imageVmName -Force
        Set-AzVm -ResourceGroupName $imageVmRg -Name $imageVmName -Generalized

        Write-Output "Generalized"
      '''
    }
  }
}
