param fslogix bool
param hostPoolType string
param location string
//param privateEndpointNameConv string
//param privateEndpointNICNameConv string
param recoveryServicesVaultName string
param fslogixStorageSolution string
param tags object
param timeZone string

resource vault 'Microsoft.recoveryServices/vaults@2022-03-01' = {
  name: recoveryServicesVaultName
  location: location
  tags: tags[?'Microsoft.RecoveryServices/vaults'] ?? {}
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
  tags: tags[?'Microsoft.RecoveryServices/vaults'] ?? {}
  properties: {
    backupManagementType: 'AzureStorage'
    schedulePolicy: {
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '23:00'
      ]
      schedulePolicyType: 'SimpleSchedulePolicy'
    }
    retentionPolicy: {
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
    timeZone: timeZone
    workLoadType: 'AzureFileShare'
  }
}

resource backupPolicy_Vm 'Microsoft.recoveryServices/vaults/backupPolicies@2022-03-01' = if (contains(hostPoolType, 'Personal')) {
  parent: vault
  name: 'AvdPolicyVm'
  location: location
  tags: tags[?'Microsoft.RecoveryServices/vaults'] ?? {}
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRpRetentionRangeInDays: 2
    policyType: 'V2'
    retentionPolicy: {
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
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicyV2'
      scheduleRunFrequency: 'Daily'
      dailySchedule: {
        scheduleRunTimes: [
          '23:00'
        ]
      }
    }
    timeZone: timeZone
  }
}

/* for later
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'AzureBackup'), 'RESOURCE', recoveryServicesVaultName), 'VNETID', '${split(subnetId, '/')[8]}')
  location: location
  tags: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
  properties: {
    customNetworkInterfaceName: replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'AzureBackup'), 'RESOURCE', recoveryServicesVaultName), 'VNETID', '${split(subnetId, '/')[8]}')
    privateLinkServiceConnections: [
      {
        name: '${recoveryServicesVaultName}-AzureBackup'
        properties: {
          privateLinkServiceId: vault.id
          groupIds: [
            'AzureBackup'
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-08-01' = {
  parent: privateEndpoint
  name: recoveryServicesVaultName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace(recoveryServicesPrivateDnsZoneResourceId, '.', '-')
        properties: {
          privateDnsZoneId: recoveryServicesPrivateDnsZoneResourceId
        }
      }
      {
        name: replace(azureQueueStoragePrivateDnsZoneResourceId, '.', '-')
        properties: {
          privateDnsZoneId: azureQueueStoragePrivateDnsZoneResourceId
        }
      }
      {
        name: replace(azureBlobsPrivateDnsZoneResourceId, '.', '-')
        properties: {
          privateDnsZoneId: azureBlobsPrivateDnsZoneResourceId
        }
      }
    ]
  }
  dependsOn: [
    vault
  ]
}
*/
