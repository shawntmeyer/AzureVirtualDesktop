param Fslogix bool
param Location string
param RecoveryServicesVaultName string
param StorageSolution string
param Tags object
param TimeZone string

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

resource vault 'Microsoft.RecoveryServices/vaults@2022-03-01' = {
  name: RecoveryServicesVaultName
  location: Location
  tags: Tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {}
}

resource backupPolicy_Storage 'Microsoft.RecoveryServices/vaults/backupPolicies@2022-03-01' = if (Fslogix && StorageSolution == 'AzureFiles') {
  parent: vault
  name: 'AvdPolicyStorage'
  location: Location
  tags: Tags
  properties: {
    backupManagementType: 'AzureStorage'
    schedulePolicy: BackupSchedulePolicy
    retentionPolicy: BackupRetentionPolicy
    timeZone: TimeZone
    workLoadType: 'AzureFileShare'
  }
}

resource backupPolicy_Vm 'Microsoft.RecoveryServices/vaults/backupPolicies@2022-03-01' = if (!Fslogix) {
  parent: vault
  name: 'AvdPolicyVm'
  location: Location
  tags: Tags
  properties: {
    backupManagementType: 'AzureIaasVM'
    schedulePolicy: BackupSchedulePolicy
    retentionPolicy: BackupRetentionPolicy
    timeZone: TimeZone
    instantRpRetentionRangeInDays: 2
  }
}
