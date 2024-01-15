param artifactsUri string
param automationAccountName string
param fslogixContainerType string
param location string
param storageAccountNamePrefix string
param storageCount int
param storageIndex int
param StorageResourceGroupName string
param tags object
param timeStamp string
param timeZone string

var RunbookName = 'Auto-Increase-Premium-File-Share-Quota'
var SubscriptionId = subscription().subscriptionId

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: automationAccountName
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccount
  name: RunbookName
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    publishContentLink: {
      uri: '${artifactsUri}Set-FileShareScaling.ps1'
      version: '1.0.0.0'
    }
  }
}

module schedules 'schedules.bicep' = [for i in range(storageIndex, storageCount): {
  name: 'Schedules_${i}_${timeStamp}'
  params: {
    automationAccountName: automationAccount.name
    fslogixContainerType: fslogixContainerType
    StorageAccountName: '${storageAccountNamePrefix}${padLeft(i, 2, '0')}'
    timeZone: timeZone
  }
}]

module jobSchedules 'jobSchedules.bicep' = [for i in range(storageIndex, storageCount): {
  name: 'JobSchedules_${i}_${timeStamp}'
  params: {
    automationAccountName: automationAccount.name
    environmentShortName: environment().name
    fslogixContainerType: fslogixContainerType
    RunbookName: RunbookName
    ResourceGroupName: StorageResourceGroupName
    StorageAccountName: '${storageAccountNamePrefix}${padLeft(i, 2, '0')}'
    SubscriptionId: SubscriptionId
    timeStamp: timeStamp
  }
  dependsOn: [
    runbook
    schedules
  ]
}]

module roleAssignment '../roleAssignment.bicep' = {
  name: 'RoleAssignment_${StorageResourceGroupName}_${timeStamp}'
  scope: resourceGroup(StorageResourceGroupName)
  params: {
    PrincipalId: automationAccount.identity.principalId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor
  }
}
