param location string
param userAssignedIdentityClientId string
param virtualMachineName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: virtualMachineName
}

resource removeVirtualMachine 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  parent: virtualMachine
  name: 'RunCommand'
  location: location
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: true
    parameters: [
      {
        name: 'environmentShortName'
        value: environment().name
      }
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'SubscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'TenantId'
        value: tenant().tenantId
      }
      {
        name: 'userAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'virtualMachineName'
        value: virtualMachineName
      }

    ]
    source: {
      script: '''
        param(
          [string]$environmentShortName,
          [string]$ResourceGroupName,
          [string]$SubscriptionId,
          [string]$TenantId,
          [string]$userAssignedIdentityClientId,
          [string]$virtualMachineName
        )
        Connect-AzAccount -environmentShortName $environmentShortName -Tenant $TenantId -Subscription $SubscriptionId -Identity -AccountId $userAssignedIdentityClientId
        ## Introduce a wait here because every Run Command will require at least 20 seconds to complete. This avoids a condition where the VM gets deleted before the output of this command is returned to the deployment.
        Start-Sleep -Seconds 20
        Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $virtualMachineName -NoWait -Force
      '''
    }
  }
}
