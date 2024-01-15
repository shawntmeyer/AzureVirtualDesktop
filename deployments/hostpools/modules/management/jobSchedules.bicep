param automationAccountName string
param environmentShortName string
param fslogixContainerType string
param ResourceGroupName string
param RunbookName string
param StorageAccountName string
param SubscriptionId string
param timeStamp string

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: automationAccountName
}

resource jobSchedules_ProfileContainers 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = [for i in range(0, 4): {
  parent: automationAccount
  name: guid(timeStamp, RunbookName, StorageAccountName, 'ProfileContainers', string(i))
  properties: {
    parameters: {
      environmentShortName: environmentShortName
      FileShareName: 'profile-containers'
      ResourceGroupName: ResourceGroupName
      StorageAccountName: StorageAccountName
      SubscriptionId: SubscriptionId
    }
    runbook: {
      name: RunbookName
    }
    runOn: null
    schedule: {
      name: '${StorageAccountName}_ProfileContainers_${(i + 1) * 15}min'
    }
  }
}]

resource jobSchedules_OfficeContainers 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = [for i in range(0, 4): if (contains(fslogixContainerType, 'Office')) {
  parent: automationAccount
  name: guid(timeStamp, RunbookName, StorageAccountName, 'OfficeContainers', string(i))
  properties: {
    parameters: {
      environmentShortName: environmentShortName
      FileShareName: 'office-containers'
      ResourceGroupName: ResourceGroupName
      StorageAccountName: StorageAccountName
      SubscriptionId: SubscriptionId
    }
    runbook: {
      name: RunbookName
    }
    runOn: null
    schedule: {
      name: '${StorageAccountName}_OfficeContainers_${(i + 1) * 15}min'
    }
  }
}]
