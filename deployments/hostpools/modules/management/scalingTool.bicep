param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param automationAccountName string
param BeginPeakTime string
param EndPeakTime string
param hostPoolName string
param HostPoolResourceGroupName string
param LimitSecondsToForceLogOffUser string
param location string
param managementVMName string
param MinimumNumberOfRdsh string
param resourceGroupManagement string
param resourceGroupHosts string
param runBookUpdateUserAssignedIdentityClientId string
param SessionThresholdPerCPU string
param tags object
param timeDifference string
param Time string = utcNow('u')
param timeStamp string
param timeZone string

var RoleAssignments = [
  resourceGroupManagement
  resourceGroupHosts
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

var runBookName = 'Scaling-Tool'

var scriptParams = '-automationAccountName ${automationAccountName} -ResourceGroupName ${resourceGroup().name} -RunBookName ${runBookName} -ScriptPath \'Set-HostPoolScaling.ps1\' -environmentShortName ${environment().name} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -userAssignedIdentityClientId ${runBookUpdateUserAssignedIdentityClientId}'

//var CommandToExecute = 'Powershell.exe -executionpolicy bypass -command .\\Update-RunbookviaCSE.ps1 ${ScriptParams}'

//var SasToken = !empty(artifactsStorageAccountResourceId) ? storageAccount.listAccountSas('2023-01-01',accountSasProperties).accountSasToken : ''

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: automationAccountName
}

/*
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if(artifactsStorageAccountResourceId != '') {
  name: last(split(artifactsStorageAccountResourceId, '/'))
  scope: resourceGroup(split(artifactsStorageAccountResourceId, '/')[2], split(artifactsStorageAccountResourceId, '/')[4])
}
*/

// Update Runbook via ManagementVM
/*
resource runbook 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  name: '${managementVMName}/CustomScriptExtension'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${artifactsUri}Update-RunBookviaCSE.ps1'
        '${artifactsUri}Set-HostPoolScaling.ps1'    
      ]
      timeStamp: timeStamp
    }    
    protectedSettings: contains(artifactsUri, environment().suffixes.storage) ? {
      commandToExecute: CommandToExecute
      managedIdentity: { clientId: artifactsUserAssignedIdentityClientId }
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
  location: location
  tags: tagsAutomationAccounts
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
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    publishContentLink: {
      uri: !empty(SasToken) ? '${artifactsUri}Set-HostPoolScaling.ps1?${SasToken}' : '${artifactsUri}Set-HostPoolScaling.ps1'
      version: '1.0.0.0'
    }
  }
}
*/

resource schedules 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = [for i in range(0, 4): {
  parent: automationAccount
  name: '${hostPoolName}_${(i + 1) * 15}min'
  properties: {
    advancedSchedule: {}
    description: null
    expiryTime: null
    frequency: 'Hour'
    interval: 1
    startTime: dateTimeAdd(Time, 'PT${(i + 1) * 15}M')
    timeZone: timeZone
  }
}]

resource jobSchedules 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = [for i in range(0, 4): {
  parent: automationAccount
  #disable-next-line use-stable-resource-identifiers
  name: guid(Time, runBookName, hostPoolName, string(i))
  properties: {
    parameters: {
      BeginPeakTime: BeginPeakTime
      EndPeakTime: EndPeakTime
      EnvironmentName: environment().name
      hostPoolName: hostPoolName
      LimitSecondsToForceLogOffUser: LimitSecondsToForceLogOffUser
      LogOffMessageBody: 'Your session will be logged off. Please save and close everything.'
      LogOffMessageTitle: 'Machine is about to shutdown.'
      MaintenanceTagName: 'Maintenance'
      MinimumNumberOfRDSH: MinimumNumberOfRdsh
      ResourceGroupName: HostPoolResourceGroupName
      SessionThresholdPerCPU: SessionThresholdPerCPU
      SubscriptionId: subscription().subscriptionId
      TenantId: subscription().tenantId
      timeDifference: timeDifference
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

module runbook '../../../sharedModules/custom/customScriptExtension.bicep' = {
  name: 'Runbook_${timeStamp}'  
  params:{
    commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Update-RunbookviaCSE.ps1 ${scriptParams}'
    fileUris: [
      '${artifactsUri}Update-RunbookviaCSE.ps1'
      '${artifactsUri}Set-HostPoolScaling.ps1'
    ]
    location: location
    output: false
    tags: tags
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVMName
  }
}

// Gives the Automation Account the "Desktop Virtualization Power On Off Contributor" role on the resource groups containing the hosts and host pool
module roleAssignment '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = [for i in range(0, length(RoleAssignments)): {
  name: 'RoleAssignment_${i}_${RoleAssignments[i]}'
  scope: resourceGroup(RoleAssignments[i])
  params: {
    principalId: automationAccount.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '40c5ff49-9181-41f8-ae61-143b0e78555e' // Desktop Virtualization Power On Off Contributor
  }
}]
