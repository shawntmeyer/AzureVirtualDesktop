param automationAccountName string
param automationAccountPrivateDnsZoneResourceId string
param location string
param logAnalyticsWorkspaceResourceId string
param enableInsights bool
param privateEndpoint bool
param privateEndpointNameConv string
param subnetResourceId string
param tags object
param virtualMachineName string

var privateEndpointName = replace(replace(privateEndpointNameConv, 'subresource', 'DSCAndHybridWorker'), 'resource', automationAccountName)

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: virtualMachineName
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: automationAccountName
  location: location
  tags: contains(tags, 'Microsoft.Automation/automationAccounts') ? tags['Microsoft.Automation/automationAccounts'] : {}
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Free'
    }
    publicNetworkAccess: privateEndpoint ? false : true
  }
}

resource automationAccountPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = if(privateEndpoint) {
  name: privateEndpointName
  location: location
  tags: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: automationAccount.id
          groupIds: [
            'DSCAndHybridWorker'
          ]
        }
      }
    ]
    customNetworkInterfaceName: 'nic-${automationAccountName}'
    subnet: {
      id: subnetResourceId
    }
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = if(!empty(automationAccountPrivateDnsZoneResourceId) && privateEndpoint) {
  parent: automationAccountPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: !empty(automationAccountPrivateDnsZoneResourceId) ? replace(last(split(automationAccountPrivateDnsZoneResourceId, '/')), '.', '-') : ''
        properties: {
          privateDnsZoneId: !empty(automationAccountPrivateDnsZoneResourceId) ? automationAccountPrivateDnsZoneResourceId : ''
        }
      }
    ]
  }
}

// Enables logging in a log analytics workspace for alerting and dashboards
resource diagnostics 'Microsoft.Insights/diagnosticsettings@2017-05-01-preview' = if (enableInsights) {
  scope: automationAccount
  name: 'diag-${automationAccountName}'
  properties: {
    logs: [
      {
        category: 'DscNodeStatus'
        enabled: true
      }
      {
        category: 'JobLogs'
        enabled: true
      }
      {
        category: 'JobStreams'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspaceResourceId
  }
}

resource hybridRunbookWorkerGroup 'Microsoft.Automation/automationAccounts/hybridRunbookWorkerGroups@2022-08-08' = {
  parent: automationAccount
  name: 'Premium File Share Increase Quota'
}

resource hybridRunbookWorker 'Microsoft.Automation/automationAccounts/hybridRunbookWorkerGroups/hybridRunbookWorkers@2022-08-08' = {
  parent: hybridRunbookWorkerGroup
  name: guid(hybridRunbookWorkerGroup.id)
  properties: {
    vmResourceId: virtualMachine.id
  }
}

resource extension_HybridWorker 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: virtualMachine
  name: 'HybridWorkerForWindows'
  location: location
  tags: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}
  properties: {
    publisher: 'Microsoft.Azure.Automation.HybridWorker'
    type: 'HybridWorkerForWindows'
    typeHandlerVersion: '1.1'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      AutomationAccountURL: automationAccount.properties.automationHybridServiceUrl
    }
  }
}

output hybridRunbookWorkerGroupName string = hybridRunbookWorkerGroup.name
