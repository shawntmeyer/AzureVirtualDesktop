param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param automationAccountName string
param deploymentUserAssignedIdentityClientId string
param fslogixContainerType string
param location string
param managementVirtualMachineName string
param storageAccountNamePrefix string
param fslogixStorageCount int
param fslogixStorageIndex int
param storageResourceGroupName string
param tags object
param timeStamp string
param timeZone string

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: automationAccountName
}

module runbook '../../../sharedModules/custom/customScriptExtension.bicep' = {
  name: 'Runbook_QuotaScaling_${timeStamp}'
  params: {
    commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Set-AutomationRunbook.ps1 -AutomationAccountName ${automationAccountName} -Environment ${environment().name} -ResourceGroupName ${resourceGroup().name} -RunbookFileName Set-FileShareScaling.ps1 -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${deploymentUserAssignedIdentityClientId}'
    fileUris: [
      '${artifactsUri}Set-FileShareScaling.ps1'
      '${artifactsUri}Set-AutomationRunbook.ps1'    
    ]
    location: location
    output: false
    tags: tags[?'Microsoft.Compute/virtualMachines'] ?? {}
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
}

module schedules 'schedules.bicep' = [for i in range(fslogixStorageIndex, fslogixStorageCount): {
  name: 'Schedules_${i}_${timeStamp}'
  params: {
    automationAccountName: automationAccount.name
    fslogixContainerType: fslogixContainerType
    storageAccountName: '${storageAccountNamePrefix}${i}'
    timeZone: timeZone
  }
}]

module jobSchedules 'jobSchedules.bicep' = [for i in range(fslogixStorageIndex, fslogixStorageCount): {
  name: 'JobSchedules_${i}_${timeStamp}'
  params: {
    automationAccountName: automationAccount.name
    environment: environment().name
    fslogixContainerType: fslogixContainerType
    runbookName: 'Set-FileShareScaling'
    resourceGroupName: storageResourceGroupName
    storageAccountName: '${storageAccountNamePrefix}${i}'
    subscriptionId: subscription().subscriptionId
    timeStamp: timeStamp
  }
  dependsOn: [
    runbook
    schedules
  ]
}]

module roleAssignment '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = {
  name: 'RoleAssignment_${storageResourceGroupName}_${timeStamp}'
  scope: resourceGroup(storageResourceGroupName)
  params: {
    principalId: automationAccount.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor
  }
}
