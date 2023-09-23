param ArtifactsLocation string
param ArtifactsStorageAccountResourceId string
param AutomationAccountName string
param BeginPeakTime string
param EndPeakTime string
param HostPoolName string
param HostPoolResourceGroupName string
param LimitSecondsToForceLogOffUser string
param Location string
param MinimumNumberOfRdsh string
param ResourceGroupControlPlane string
param ResourceGroupHosts string
param SessionThresholdPerCPU string
param Tags object
param TimeDifference string
param Time string = utcNow('u')
param TimeZone string

var RoleAssignments = [
  ResourceGroupControlPlane
  ResourceGroupHosts
]

var sasTokenValidityLength = 'PT1H'

var accountSasProperties = {
  signedServices: 'b'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(Time, sasTokenValidityLength)
  signedResourceTypes: 'o'
  signedProtocol: 'https'
}

var SasToken = !empty(ArtifactsStorageAccountResourceId) ? storageAccount.listAccountSas('2023-01-01',accountSasProperties).accountSasToken : ''

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: AutomationAccountName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if(ArtifactsStorageAccountResourceId != '') {
  name: last(split(ArtifactsStorageAccountResourceId, '/'))
  scope: resourceGroup(split(ArtifactsStorageAccountResourceId, '/')[2], split(ArtifactsStorageAccountResourceId, '/')[4])
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccount
  name: 'Scaling-Tool'
  location: Location
  tags: Tags
  properties: {
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    publishContentLink: {
      uri: !empty(SasToken) ? '${ArtifactsLocation}Set-HostPoolScaling.ps1?${SasToken}' : '${ArtifactsLocation}Set-HostPoolScaling.ps1'
      version: '1.0.0.0'
    }
  }
}

resource schedules 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = [for i in range(0, 4): {
  parent: automationAccount
  name: '${HostPoolName}_${(i + 1) * 15}min'
  properties: {
    advancedSchedule: {}
    description: null
    expiryTime: null
    frequency: 'Hour'
    interval: 1
    startTime: dateTimeAdd(Time, 'PT${(i + 1) * 15}M')
    timeZone: TimeZone
  }
}]

resource jobSchedules 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = [for i in range(0, 4): {
  parent: automationAccount
  #disable-next-line use-stable-resource-identifiers
  name: guid(Time, runbook.name, HostPoolName, string(i))
  properties: {
    parameters: {
      BeginPeakTime: BeginPeakTime
      EndPeakTime: EndPeakTime
      EnvironmentName: environment().name
      HostPoolName: HostPoolName
      LimitSecondsToForceLogOffUser: LimitSecondsToForceLogOffUser
      LogOffMessageBody: 'Your session will be logged off. Please save and close everything.'
      LogOffMessageTitle: 'Machine is about to shutdown.'
      MaintenanceTagName: 'Maintenance'
      MinimumNumberOfRDSH: MinimumNumberOfRdsh
      ResourceGroupName: HostPoolResourceGroupName
      SessionThresholdPerCPU: SessionThresholdPerCPU
      SubscriptionId: subscription().subscriptionId
      TenantId: subscription().tenantId
      TimeDifference: TimeDifference
    }
    runbook: {
      name: runbook.name
    }
    runOn: null
    schedule: {
      name: schedules[i].name
    }
  }
}]


// Gives the Automation Account the "Desktop Virtualization Power On Off Contributor" role on the resource groups containing the hosts and host pool
module roleAssignment '../roleAssignment.bicep' = [for i in range(0, length(RoleAssignments)): {
  name: 'RoleAssignment_${i}_${RoleAssignments[i]}'
  scope: resourceGroup(RoleAssignments[i])
  params: {
    PrincipalId: automationAccount.identity.principalId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: '40c5ff49-9181-41f8-ae61-143b0e78555e' // Desktop Virtualization Power On Off Contributor
  }
}]

output runbookUri string = !empty(SasToken) ? '${ArtifactsLocation}Set-HostPoolScaling.ps1?${SasToken}' : '${ArtifactsLocation}Set-HostPoolScaling.ps1'
