param ArtifactsLocation string
param ArtifactsUserAssignedIdentityClientId string
//param ArtifactsStorageAccountResourceId string
param AutomationAccountName string
param BeginPeakTime string
param EndPeakTime string
param HostPoolName string
param HostPoolResourceGroupName string
param LimitSecondsToForceLogOffUser string
param Location string
param ManagementVMName string
param MinimumNumberOfRdsh string
param ResourceGroupControlPlane string
param ResourceGroupHosts string
param RunBookUpdateUserAssignedIdentityClientId string
param SessionThresholdPerCPU string
param TagsVirtualMachines object
param TimeDifference string
param Time string = utcNow('u')
param Timestamp string
param TimeZone string

var RoleAssignments = [
  ResourceGroupControlPlane
  ResourceGroupHosts
]

/* Commented out for Zero Trust approach.
var sasTokenValidityLength = 'PT1H'


var accountSasProperties = {
  signedServices: 'b'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(Time, sasTokenValidityLength)
  signedResourceTypes: 'o'
  signedProtocol: 'https'
}
*/

var RunBookName = 'Scaling-Tool'

var ScriptParams = '-AutomationAccountName ${AutomationAccountName} -ResourceGroupName ${resourceGroup().name} -RunBookName ${RunBookName} -ScriptPath \'Set-HostPoolScaling.ps1\' -Environment ${environment().name} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${RunBookUpdateUserAssignedIdentityClientId}'

//var CommandToExecute = 'Powershell.exe -executionpolicy bypass -command .\\Update-RunbookviaCSE.ps1 ${ScriptParams}'

//var SasToken = !empty(ArtifactsStorageAccountResourceId) ? storageAccount.listAccountSas('2023-01-01',accountSasProperties).accountSasToken : ''

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: AutomationAccountName
}

/*
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if(ArtifactsStorageAccountResourceId != '') {
  name: last(split(ArtifactsStorageAccountResourceId, '/'))
  scope: resourceGroup(split(ArtifactsStorageAccountResourceId, '/')[2], split(ArtifactsStorageAccountResourceId, '/')[4])
}
*/

// Update Runbook via ManagementVM
/*
resource runbook 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  name: '${ManagementVMName}/CustomScriptExtension'
  location: Location
  tags: TagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${ArtifactsLocation}Update-RunBookviaCSE.ps1'
        '${ArtifactsLocation}Set-HostPoolScaling.ps1'    
      ]
      timestamp: Timestamp
    }    
    protectedSettings: contains(ArtifactsLocation, environment().suffixes.storage) ? {
      commandToExecute: CommandToExecute
      managedIdentity: { clientId: ArtifactsUserAssignedIdentityClientId }
    } : {
      commandToExecute: CommandToExecute
    }
  }
  dependsOn: [
  ]
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccount
  name: RunBookName
  location: Location
  tags: TagsAutomationAccounts
  properties: {
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
  }
}
*/
/*
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
*/

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
  name: guid(Time, RunBookName, HostPoolName, string(i))
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
      name: runbook.outputs.value.RunbookName
    }
    runOn: null
    schedule: {
      name: schedules[i].name
    }
  }
}]

module runbook 'customScriptExtensions.bicep' = {
  name: 'Runbook_${Timestamp}'  
  params:{
    ArtifactsLocation: ArtifactsLocation
    ExecuteScript: 'Update-RunbookviaCSE.ps1'
    Files: [
      'Update-RunbookviaCSE.ps1'
      'Set-HostPoolScaling.ps1'
    ]
    Location: Location
    Output: true
    Parameters: ScriptParams
    Tags: TagsVirtualMachines
    UserAssignedIdentityClientId: ArtifactsUserAssignedIdentityClientId
    VirtualMachineName: ManagementVMName
  }
}

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

//output runbookUri string = !empty(SasToken) ? '${ArtifactsLocation}Set-HostPoolScaling.ps1?${SasToken}' : '${ArtifactsLocation}Set-HostPoolScaling.ps1'
