param desktopFriendlyName string
param desktopAppGroupName string
param desktopAppGroupResourceGroup string
param Cloud string = environment().name
param location string
param managementVirtualMachineName string
param userAssignedIdentityClientId string

resource managementVm 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: managementVirtualMachineName
}

resource updatedesktopFriendlyName 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'Update-Desktop-Friendly-Name'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: true
    parameters: [
      {
        name: 'desktopFriendlyName'
        value: desktopFriendlyName
      }
      {
        name: 'desktopAppGroupName'
        value: desktopAppGroupName
      }
      {
        name: 'desktopAppGroupResourceGroup'
        value: desktopAppGroupResourceGroup
      }
      {
        name: 'environmentShortName'
        value: Cloud
      }
      {
        name: 'userAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
    ]
    source: {
      script: '''
        param(
          [string]$desktopFriendlyName,
          [string]$desktopAppGroupName,
          [string]$desktopAppGroupResourceGroup,
          [string]$environmentShortName,
          [string]$userAssignedIdentityClientId
        )
        # Connect to Azure
        Connect-AzAccount -Identity -AccountId $userAssignedIdentityClientId -environmentShortName $environmentShortName # Run on the virtual machine
        $Desktop = Get-AzWvdDesktop -ApplicationGroupName $desktopAppGroupName -ResourceGroupName $desktopAppGroupResourceGroup
        If ($($Desktop.friendlyName) -ne $desktopFriendlyName) {
          $Desktop | Update-AzWvdDesktop -friendlyName $desktopFriendlyName
        }
        Disconnect-AzAccount
      '''
    }
  }
}
