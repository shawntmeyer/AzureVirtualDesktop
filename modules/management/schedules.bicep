param automationAccountName string
param fslogixContainerType string
param StorageAccountName string
param Time string = utcNow()
param timeZone string

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: automationAccountName
}

resource schedules_ProfileContainers 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = [for i in range(0, 4): {
  parent: automationAccount
  name: '${StorageAccountName}_ProfileContainers_${(i + 1) * 15}min'
  properties: {
    advancedSchedule: {}
    description: null
    expiryTime: null
    frequency: 'Hour'
    interval: 1
    startTime: dateTimeAdd(Time, 'PT${(i + 1) * 15}M')
    timeZone: timeZone
  }
}]

resource schedules_OfficeContainers 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = [for i in range(0, 4): if (contains(fslogixContainerType, 'Office')) {
  parent: automationAccount
  name: '${StorageAccountName}_OfficeContainers_${(i + 1) * 15}min'
  properties: {
    advancedSchedule: {}
    description: null
    expiryTime: null
    frequency: 'Hour'
    interval: 1
    startTime: dateTimeAdd(Time, 'PT${(i + 1) * 15}M')
    timeZone: timeZone
  }
}]
