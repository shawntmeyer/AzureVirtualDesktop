param fslogix bool
param location string
param recoveryServicesVaultName string
param fslogixStorageSolution string
param tags object
param timeZone string

var BackupSchedulePolicy = {
  scheduleRunFrequency: 'Daily'
  scheduleRunTimes: [
    '23:00'
  ]
  schedulePolicyType: 'SimpleSchedulePolicy'
}
var BackupRetentionPolicy = {
  retentionPolicyType: 'LongTermRetentionPolicy'
  dailySchedule: {
    retentionTimes: [
      '23:00'
    ]
    retentionDuration: {
      count: 30
      durationType: 'Days'
    }
  }
}

resource vault 'Microsoft.recoveryServices/vaults@2022-03-01' = {
  name: recoveryServicesVaultName
  location: location
  tags: tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {}
}

resource backupPolicy_Storage 'Microsoft.recoveryServices/vaults/backupPolicies@2022-03-01' = if (fslogix && fslogixStorageSolution == 'AzureFiles') {
  parent: vault
  name: 'AvdPolicyStorage'
  location: location
  tags: tags
  properties: {
    backupManagementType: 'AzureStorage'
    schedulePolicy: BackupSchedulePolicy
    retentionPolicy: BackupRetentionPolicy
    timeZone: timeZone
    workLoadType: 'AzureFileShare'
  }
}

resource backupPolicy_Vm 'Microsoft.recoveryServices/vaults/backupPolicies@2022-03-01' = if (!fslogix) {
  parent: vault
  name: 'AvdPolicyVm'
  location: location
  tags: tags
  properties: {
    backupManagementType: 'AzureIaasVM'
    schedulePolicy: BackupSchedulePolicy
    retentionPolicy: BackupRetentionPolicy
    timeZone: timeZone
    instantRpRetentionRangeInDays: 2
  }
}
