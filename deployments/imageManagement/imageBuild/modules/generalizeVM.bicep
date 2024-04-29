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

// This resource block deploys a run command on a virtual machine to generalize it.
// The run command executes a PowerShell script that connects to Azure, generalizes the virtual machine, and outputs a message.
// It requires the following parameters:
// - UserAssignedIdentityClientId: The client ID of the user-assigned identity used to authenticate with Azure.
// - ImageVmRg: The resource group of the virtual machine to be generalized.
// - ImageVmName: The name of the virtual machine to be generalized.
// - Environment: The Azure environment to connect to.
// The script connects to Azure using the provided identity, waits for the virtual machine to be available, and then generalizes it using PowerShell commands.
// Finally, it outputs a message indicating that the virtual machine has been generalized.
