metadata name = 'Public IP Addresses'
metadata description = 'This module deploys a Public IP Address.'
metadata owner = 'Azure/module-maintainers'

@description('Required. The name of the Public IP Address.')
param name string

@description('Optional. Resource ID of the Public IP Prefix object. This is only needed if you want your Public IPs created in a PIP Prefix.')
param publicIPPrefixResourceId string = ''

@description('Optional. The public IP address allocation method.')
@allowed([
  'Dynamic'
  'Static'
])
param publicIPAllocationMethod string = 'Static'

@description('Optional. Name of a public IP address SKU.')
@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Standard'

@description('Optional. Tier of a public IP address SKU.')
@allowed([
  'Global'
  'Regional'
])
param skuTier string = 'Regional'

@description('Optional. A list of availability zones denoting the IP allocated for the resource needs to come from.')
param zones array = []

@description('Optional. IP address version.')
@allowed([
  'IPv4'
  'IPv6'
])
param publicIPAddressVersion string = 'IPv4'

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the diagnostic log analytics workspace.')
param diagnosticWorkspaceId string = ''

@description('Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param diagnosticEventHubAuthorizationRuleId string = ''

@description('Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param diagnosticEventHubName string = ''

@description('Optional. The domain name label. The concatenation of the domain name label and the regionalized DNS zone make up the fully qualified domain name associated with the public IP address. If a domain name label is specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system.')
param domainNameLabel string = ''

@allowed([
  ''
  'NoReuse'
  'ResourceGroupReuse'
  'SubscriptionReuse'
  'TenantReuse'
])
@description('Optional. The domain name label scope. If a domain name label and a domain name label scope are specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system with a hashed value includes in FQDN.')
param domainNameLabelScope string = ''

@description('Optional. The Fully Qualified Domain Name of the A DNS record associated with the public IP. This is the concatenation of the domainNameLabel and the regionalized DNS zone.')
param fqdn string = ''

@description('Optional. The reverse FQDN. A user-visible, fully qualified domain name that resolves to this public IP address. If the reverseFqdn is specified, then a PTR DNS record is created pointing from the IP address in the in-addr.arpa domain to the reverse FQDN.')
param reverseFqdn string = ''

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. The name of logs that will be streamed. "allLogs" includes all possible logs for the resource. Set to \'\' to disable log collection.')
@allowed([
  ''
  'allLogs'
  'DDoSProtectionNotifications'
  'DDoSMitigationFlowLogs'
  'DDoSMitigationReports'
])
param diagnosticLogCategoriesToEnable array = [
  'allLogs'
]

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'AllMetrics'
])
param diagnosticMetricsToEnable array = [
  'AllMetrics'
]

@description('Optional. The name of the diagnostic setting, if deployed. If left empty, it defaults to "<resourceName>-diagnosticSettings".')
param diagnosticSettingsName string = ''

var diagnosticsLogsSpecified = [for category in filter(diagnosticLogCategoriesToEnable, item => item != 'allLogs' && item != ''): {
  category: category
  enabled: true
}]

var diagnosticsLogs = contains(diagnosticLogCategoriesToEnable, 'allLogs') ? [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
] : contains(diagnosticLogCategoriesToEnable, '') ? [] : diagnosticsLogsSpecified

var diagnosticsMetrics = [for metric in diagnosticMetricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
}]

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  zones: zones
  properties: {
    dnsSettings: !empty(domainNameLabel) ? {
      domainNameLabel: domainNameLabel
      domainNameLabelScope: !empty(domainNameLabelScope) ? domainNameLabelScope == 'NoReuse' ? 'NoReuse' : domainNameLabelScope == 'ResourceGroupReuse' ? 'ResourceGroupReuse' : domainNameLabelScope == 'SubscriptionReuse' ? 'SubscriptionReuse' : 'TenantReuse' : null
      fqdn: fqdn
      reverseFqdn: reverseFqdn
    } : null
    publicIPAddressVersion: publicIPAddressVersion
    publicIPAllocationMethod: publicIPAllocationMethod
    publicIPPrefix: !empty(publicIPPrefixResourceId) ? {
      id: publicIPPrefixResourceId
    } : null
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}

resource publicIpAddress_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticStorageAccountId) || !empty(diagnosticWorkspaceId) || !empty(diagnosticEventHubAuthorizationRuleId) || !empty(diagnosticEventHubName)) {
  name: !empty(diagnosticSettingsName) ? diagnosticSettingsName : '${name}-diagnosticSettings'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    eventHubAuthorizationRuleId: !empty(diagnosticEventHubAuthorizationRuleId) ? diagnosticEventHubAuthorizationRuleId : null
    eventHubName: !empty(diagnosticEventHubName) ? diagnosticEventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: publicIpAddress
}

@description('The resource group the public IP address was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name of the public IP address.')
output name string = publicIpAddress.name

@description('The resource ID of the public IP address.')
output resourceId string = publicIpAddress.id

@description('The public IP address of the public IP address resource.')
output ipAddress string = publicIpAddress.properties.?ipAddress ?? ''

@description('The location the resource was deployed into.')
output location string = publicIpAddress.location
