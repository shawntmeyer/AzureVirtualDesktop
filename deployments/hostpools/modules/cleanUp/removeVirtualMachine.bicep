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
        name: 'Environment'
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
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'VirtualMachineName'
        value: virtualMachineName
      }

    ]
    source: {
      script: '''
        param(
          [string]$Environment,
          [string]$ResourceGroupName,
          [string]$SubscriptionId,
          [string]$TenantId,
          [string]$UserAssignedIdentityClientId,
          [string]$VirtualMachineName
        )
        Connect-AzAccount -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId -Identity -AccountId $UserAssignedIdentityClientId
        ## Introduce a wait here because every Run Command will require at least 20 seconds to complete. This avoids a condition where the VM gets deleted before the output of this command is returned to the deployment.
        Start-Sleep -Seconds 20
        Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -NoWait -Force
      '''
    }
  }
}
