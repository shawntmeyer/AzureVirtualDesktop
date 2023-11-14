param ActiveDirectorySolution string
param CustomRdpProperty string
param HostPoolName string
param HostPoolType string
param Location string
param LogAnalyticsWorkspaceResourceId string
param MaxSessionLimit int
param Monitoring bool
param TagsHostPool object
param Time string = utcNow('u')
param ValidationEnvironment bool
param VmTemplate string

var CustomRdpProperty_Complete = contains(ActiveDirectorySolution, 'AzureActiveDirectory') && !contains(CustomRdpProperty, 'targetisaadjoined:i:1') ? '${CustomRdpProperty};targetisaadjoined:i:1' : CustomRdpProperty
var HostPoolLogs = [
  {
    category: 'Checkpoint'
    enabled: true
  }
  {
    category: 'Error'
    enabled: true
  }
  {
    category: 'Management'
    enabled: true
  }
  {
    category: 'Connection'
    enabled: true
  }
  {
    category: 'HostRegistration'
    enabled: true
  }
  {
    category: 'AgentHealthStatus'
    enabled: true
  }
]

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2021-03-09-preview' = {
  name: HostPoolName
  location: Location
  tags: TagsHostPool
  properties: {
    hostPoolType: split(HostPoolType, ' ')[0]
    maxSessionLimit: MaxSessionLimit
    loadBalancerType: contains(HostPoolType, 'Pooled') ? split(HostPoolType, ' ')[1] : 'Persistent'
    validationEnvironment: ValidationEnvironment
    registrationInfo: {
      expirationTime: dateTimeAdd(Time, 'PT2H')
      registrationTokenOperation: 'Update'
    }
    preferredAppGroupType: 'Desktop'
    customRdpProperty: CustomRdpProperty_Complete
    personalDesktopAssignmentType: contains(HostPoolType, 'Personal') ? split(HostPoolType, ' ')[1] : null
    startVMOnConnect: true
    vmTemplate: VmTemplate

  }
}

resource hostPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (Monitoring) {
  name: 'diag-${HostPoolName}'
  scope: hostPool
  properties: {
    logs: HostPoolLogs
    workspaceId: LogAnalyticsWorkspaceResourceId
  }
}

output ResourceId string = hostPool.id
