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

var runbookFileName = 'Set-FileShareScaling.ps1'
var scriptFileName = 'Set-AutomationRunbook.ps1'
var subscriptionId = subscription().subscriptionId

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: automationAccountName
}

module runbook '../../../sharedModules/custom/customScriptExtension.bicep' = {
  name: 'Runbook_QuotaScaling_${timeStamp}'
  params: {
    artifactsLocation: artifactsUri
    files: [
      '${runbookFileName}'
      '${scriptFileName}'
    ]
    location: location
    scriptParameters: '-AutomationAccountName ${automationAccountName} -Environment ${environment().name} -ResourceGroupName ${resourceGroup().name} -RunbookFileName ${runbookFileName} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${deploymentUserAssignedIdentityClientId}'
    powerShellScriptName: scriptFileName
    tags: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
}

module schedules 'schedules.bicep' = [for i in range(fslogixStorageIndex, fslogixStorageCount): {
  name: 'Schedules_${i}_${timeStamp}'
  params: {
    automationAccountName: automationAccount.name
    fslogixContainerType: fslogixContainerType
    storageAccountName: '${storageAccountNamePrefix}${padLeft(i, 2, '0')}'
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
    storageAccountName: '${storageAccountNamePrefix}${padLeft(i, 2, '0')}'
    subscriptionId: subscriptionId
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
