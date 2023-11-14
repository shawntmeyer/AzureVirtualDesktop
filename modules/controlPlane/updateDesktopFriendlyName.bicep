param DesktopFriendlyName string
param DesktopAppGroupName string
param DesktopAppGroupResourceGroup string
param Cloud string = environment().name
param Location string
param ManagementVmName string
param UserAssignedIdentityClientId string

resource managementVm 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: ManagementVmName
}

resource updateDesktopFriendlyName 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'Update-Desktop-Friendly-Name'
  location: Location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: true
    parameters: [
      {
        name: 'DesktopFriendlyName'
        value: DesktopFriendlyName
      }
      {
        name: 'DesktopAppGroupName'
        value: DesktopAppGroupName
      }
      {
        name: 'DesktopAppGroupResourceGroup'
        value: DesktopAppGroupResourceGroup
      }
      {
        name: 'Environment'
        value: Cloud
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: UserAssignedIdentityClientId
      }
    ]
    source: {
      script: '''
        param(
          [string]$DesktopFriendlyName,
          [string]$DesktopAppGroupName,
          [string]$DesktopAppGroupResourceGroup,
          [string]$Environment,
          [string]$UserAssignedIdentityClientId
        )
        # Connect to Azure
        Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -Environment $Environment # Run on the virtual machine
        $Desktop = Get-AzWvdDesktop -ApplicationGroupName $DesktopAppGroupName -ResourceGroupName $DesktopAppGroupResourceGroup
        If ($($Desktop.FriendlyName) -ne $DesktopFriendlyName) {
          $Desktop | Update-AzWvdDesktop -FriendlyName $DesktopFriendlyName
        }
        Disconnect-AzAccount
      '''
    }
  }
}
