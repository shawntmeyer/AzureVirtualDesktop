param automationAccountName string
param automationAccountPrivateDnsZoneResourceId string
param location string
param logAnalyticsWorkspaceResourceId string
param enableInsights bool
param privateEndpoint bool
param privateEndpointNameConv string
param subnetResourceId string
param tags object

var privateEndpointName = replace(replace(privateEndpointNameConv, 'subresource', 'DSCAndHybridWorker'), 'resource', automationAccountName)

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
        id: resourceId('Microsoft.Network/privateEndpoints/privateLinkServiceConnections', privateEndpointName, privateEndpointName)
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
