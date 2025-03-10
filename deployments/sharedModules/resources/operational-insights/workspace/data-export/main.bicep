@description('Required. The data export rule name.')
@minLength(4)
@maxLength(63)
param name string

@description('Conditional. The name of the parent workspaces. Required if the template is used in a standalone deployment.')
param workspaceName string

@description('Optional. Destination properties.')
param destination object = {}

@description('Optional. Active when enabled.')
param enable bool = false

@description('Optional. An array of tables to export, for example: [\'Heartbeat\', \'SecurityEvent\'].')
param tableNames array = []

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

resource dataExport 'Microsoft.OperationalInsights/workspaces/dataExports@2020-08-01' = {
  parent: workspace
  name: name
  properties: {
    destination: destination
    enable: enable
    tableNames: tableNames
  }
}

@description('The name of the data export.')
output name string = dataExport.name

@description('The resource ID of the data export.')
output resourceId string = dataExport.id
