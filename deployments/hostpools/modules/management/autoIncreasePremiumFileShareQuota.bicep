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

var subscriptionId = subscription().subscriptionId

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: automationAccountName
}

module runbook 'runbook.bicep' = {
  name: 'Runbook_QuotaScaling_${timeStamp}'
  params: {
    artifactsUri: artifactsUri
    automationAccountName: automationAccountName
    blobName: 'Set-FileShareScaling.ps1'
    location: location
    purpose: 'quota-scaling'
    tags: tags
    userAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
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

module roleAssignment '../common/roleAssignment.bicep' = {
  name: 'RoleAssignment_${storageResourceGroupName}_${timeStamp}'
  scope: resourceGroup(storageResourceGroupName)
  params: {
    PrincipalId: automationAccount.identity.principalId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor
  }
}
