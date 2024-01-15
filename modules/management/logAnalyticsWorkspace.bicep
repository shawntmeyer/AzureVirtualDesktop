param location string
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRetention int
param logAnalyticsWorkspaceSku string
param tags object
param virtualMachineMonitoringAgent string

var WindowsEvents = virtualMachineMonitoringAgent == 'LogAnalyticsAgent' ? [
  {
    name: 'Microsoft-FSLogix-Apps/Operational'
    types: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
  {
    name: 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
    types: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
  {
    name: 'System'
    types: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
    ]
  }
  {
    name: 'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin'
    types: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
  {
    name: 'Microsoft-FSLogix-Apps/Admin'
    types: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
  {
    name: 'Application'
    types: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
    ]
  }
] : []
var WindowsPerformanceCounters = virtualMachineMonitoringAgent == 'LogAnalyticsAgent' ? [
  {
    objectName: 'LogicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Disk Transfers/sec'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Current Disk Queue Length'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Disk Reads/sec'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: '% Free Space'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Avg. Disk sec/Read'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Disk Writes/sec'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Avg. Disk sec/Write'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Free Megabytes'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: 'C:'
    intervalSeconds: 60
    counterName: '% Free Space'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: 'C:'
    intervalSeconds: 30
    counterName: 'Avg. Disk Queue Length'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: 'C:'
    intervalSeconds: 60
    counterName: 'Avg. Disk sec/Transfer'
  }
  {
    objectName: 'LogicalDisk'
    instanceName: 'C:'
    intervalSeconds: 30
    counterName: 'Current Disk Queue Length'
  }
  {
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 60
    counterName: '% Committed Bytes In Use'
  }
  {
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Available MBytes'
  }
  {
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Available Mbytes'
  }
  {
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Page Faults/sec'
  }
  {
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Pages/sec'
  }
  {
    objectName: 'Network Adapter'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Bytes Sent/sec'
  }
  {
    objectName: 'Network Adapter'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Bytes Received/sec'
  }
  {
    objectName: 'Network Interface'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Bytes Total/sec'
  }
  {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Avg. Disk Bytes/Transfer'
  }
  {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Avg. Disk Bytes/Read'
  }
  {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Avg. Disk sec/Write'
  }
  {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Avg. Disk sec/Read'
  }
  {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Avg. Disk Bytes/Write'
  }
  {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Avg. Disk sec/Transfer'
  }
  {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Avg. Disk Queue Length'
  }
  {
    objectName: 'Process'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'IO Write Operations/sec'
  }
  {
    objectName: 'Process'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'IO Read Operations/sec'
  }
  {
    objectName: 'Process'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Thread Count'
  }
  {
    objectName: 'Process'
    instanceName: '*'
    intervalSeconds: 60
    counterName: '% User Time'
  }
  {
    objectName: 'Process'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Working Set'
  }
  {
    objectName: 'Process'
    instanceName: '*'
    intervalSeconds: 60
    counterName: '% Processor Time'
  }
  {
    objectName: 'Processor'
    instanceName: '_Total'
    intervalSeconds: 60
    counterName: '% Processor Time'
  }
  {
    objectName: 'Processor Information'
    instanceName: '_Total'
    intervalSeconds: 30
    counterName: '% Processor Time'
  }
  {
    objectName: 'RemoteFX Graphics'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Frames Skipped/Second - Insufficient Server Resources'
  }
  {
    objectName: 'RemoteFX Graphics'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Average Encoding Time'
  }
  {
    objectName: 'RemoteFX Graphics'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Frames Skipped/Second - Insufficient Client Resources'
  }
  {
    objectName: 'RemoteFX Graphics'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Frames Skipped/Second - Insufficient Network Resources'
  }
  {
    objectName: 'RemoteFX Network'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Current UDP Bandwidth'
  }
  {
    objectName: 'RemoteFX Network'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Current TCP Bandwidth'
  }
  {
    objectName: 'RemoteFX Network'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Current TCP RTT'
  }
  {
    objectName: 'RemoteFX Network'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Current UDP RTT'
  }
  {
    objectName: 'System'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Processor Queue Length'
  }
  {
    objectName: 'Terminal Services'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Inactive Sessions'
  }
  {
    objectName: 'Terminal Services'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Total Sessions'
  }
  {
    objectName: 'Terminal Services'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Active Sessions'
  }
  {
    objectName: 'Terminal Services Session'
    instanceName: '*'
    intervalSeconds: 60
    counterName: '% Processor Time'
  }
  {
    objectName: 'User Input Delay per Process'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Max Input Delay'
  }
  {
    objectName: 'User Input Delay per Session'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Max Input Delay'
  }
] : []

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSku
    }
    retentionInDays: logAnalyticsWorkspaceRetention
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@batchSize(1)
resource windowsEvents 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = [for (item, i) in WindowsEvents: {
  parent: logAnalyticsWorkspace
  name: 'WindowsEvent${i}'
  tags: tags
  kind: 'WindowsEvent'
  properties: {
    eventLogName: item.name
    eventTypes: item.types
  }
}]

@batchSize(1)
resource windowsPerformanceCounters 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = [for (item, i) in WindowsPerformanceCounters: {
  parent: logAnalyticsWorkspace
  name: 'WindowsPerformanceCounter${i}'
  tags: tags
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: item.objectName
    instanceName: item.instanceName
    intervalSeconds: item.intervalSeconds
    counterName: item.counterName
  }
  dependsOn: [
    windowsEvents
  ]
}]

output ResourceId string = logAnalyticsWorkspace.id
