targetScope = 'subscription'

param dataCollectionEndpointName string
param dataCollectionRulesNameConv string
param location string
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRetention int
param logAnalyticsWorkspaceSku string
param resourceGroupMonitoring string
param tags object
param timeStamp string

module logAnalyticsWorkspace 'modules/logAnalyticsWorkspace.bicep' = {
  scope: resourceGroup(resourceGroupMonitoring)
  name: 'LogAnalytics_${timeStamp}'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRetention: logAnalyticsWorkspaceRetention
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: location
    tags: tags[?'Microsoft.OperationalInsights/workspaces'] ?? {}
  }
}

// Data Collection Rule for AVD Insights required for the Azure Monitor Agent
module avdInsightsDataCollectionRules 'modules/avdInsightsDataCollectionRules.bicep' = {
  name: 'AVDInsights_DataCollectionRule_${timeStamp}'
  scope: resourceGroup(resourceGroupMonitoring)
  params: {
    dataCollectionEndpointId: dataCollectionEndpoint.outputs.resourceId
    LogAWorkspaceId: logAnalyticsWorkspace.outputs.ResourceId
    location: location
    NameConv: dataCollectionRulesNameConv
    tags: tags[?'Microsoft.Insights/dataCollectionRules'] ?? {}
  }
}

// Data Collection Rule for VM Insights required for the Azure Monitor Agent
module vmInsightsDataCollectionRules 'modules/vmInsightsDataCollectionRules.bicep' = {
  name: 'VMInsights_DataCollectionRule_${timeStamp}'
  scope: resourceGroup(resourceGroupMonitoring)
  params: {
    dataCollectionEndpointId: dataCollectionEndpoint.outputs.resourceId
    LogAWorkspaceId: logAnalyticsWorkspace.outputs.ResourceId
    location: location
    NameConv: dataCollectionRulesNameConv
    tags: tags[?'Microsoft.Insights/dataCollectionRules'] ?? {}
  }
}

module dataCollectionEndpoint 'modules/dataCollectionEndpoint.bicep' = {
  name: 'DataCollectionEndpoint_${timeStamp}'
  scope: resourceGroup(resourceGroupMonitoring)
  params: {
    location: location
    tags: tags[?'Microsoft.Insights/dataCollectionEndpoints'] ?? {}
    name: dataCollectionEndpointName
    publicNetworkAccess: 'Enabled'
  }
}

output dataCollectionEndpointResourceId string = dataCollectionEndpoint.outputs.resourceId
output avdInsightsDataCollectionRulesResourceId string = avdInsightsDataCollectionRules.outputs.dataCollectionRulesId
output vmInsightsDataCollectionRulesResourceId string = vmInsightsDataCollectionRules.outputs.dataCollectionRulesId
output logAnalyticsWorkspaceResourceId string = logAnalyticsWorkspace.outputs.ResourceId
