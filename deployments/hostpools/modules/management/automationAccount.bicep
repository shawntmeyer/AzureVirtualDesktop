param automationAccountName string
param automationAccountPrivateDnsZoneResourceId string
param location string
param logAnalyticsWorkspaceResourceId string
param enableMonitoring bool
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param tags object
param timeStamp string
param virtualMachineName string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = if (!empty(privateEndpointSubnetResourceId)) {
  name: split(privateEndpointSubnetResourceId, '/')[8]
  scope: resourceGroup(split(privateEndpointSubnetResourceId, '/')[2], split(privateEndpointSubnetResourceId, '/')[4])
}

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

module automationAccount_privateEndpoint '../../../sharedModules/resources/network/private-endpoint/main.bicep' = if(privateEndpoint && !empty(privateEndpointSubnetResourceId)) {
  name: 'automationAccount_privateEndpoint_${timeStamp}'
  params: {
    customNetworkInterfaceName: replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'DSCAndHybridWorker'), 'RESOURCE', automationAccountName), 'VNETID', '${split(privateEndpointSubnetResourceId, '/')[8]}')
    groupIds: [
      'DSCAndHybridWorker'
    ]
    location: vnet.location
    name: replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'DSCAndHybridWorker'), 'RESOURCE', automationAccountName), 'VNETID', '${split(privateEndpointSubnetResourceId, '/')[8]}')
    privateDnsZoneGroup: {
      privateDNSResourceIds: [
        automationAccountPrivateDnsZoneResourceId
      ]
    }
    serviceResourceId: automationAccount.id
    subnetResourceId: privateEndpointSubnetResourceId
    tags: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
  }
}

// Enables logging in a log analytics workspace for alerting and dashboards
resource diagnostics 'Microsoft.Insights/diagnosticsettings@2017-05-01-preview' = if (enableMonitoring) {
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
