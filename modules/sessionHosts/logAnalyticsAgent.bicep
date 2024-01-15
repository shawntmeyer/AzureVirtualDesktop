targetScope = 'resourceGroup'
param Vms array
param location string = resourceGroup().location
param logAnalyticsWorkspaceResourceId string = '/subscriptions/e1798572-020f-46f5-937f-03f7fe916b21/resourcegroups/tt-monitoring-usgovvirginia-rg/providers/microsoft.operationalinsights/workspaces/tt-monitoring-usgovvirginia-loga'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: last(split(logAnalyticsWorkspaceResourceId, '/'))
  scope: resourceGroup(split(logAnalyticsWorkspaceResourceId, '/')[2], split(logAnalyticsWorkspaceResourceId, '/')[4])
}

module microsoftMonitoringAgent '../../../../../Common/Bicep/ResourceModules/compute/virtual-machine/extension/main.bicep' = [for vm in Vms:  {
  name: '${vm}-mma'
  params: {
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
    location: location
    name: 'MicrosoftMonitoringAgent'
    protectedSettings: {
      workspaceKey: logAnalyticsWorkspace.listkeys().primarySharedKey
    }
    publisher: 'Microsoft.EnterpriseCloud.monitoring'
    settings: {
      workspaceId: logAnalyticsWorkspace.properties.customerId
    }
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    virtualMachineName: vm
  }
}]
