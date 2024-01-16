targetScope = 'subscription'
param activeDirectorySolution string
param artifactsUri string
param artifactsStorageAccountResourceId string
param artifactsUserAssignedIdentityResourceId string
param automationAccountName string
param automationAccountPrivateDnsZoneResourceId string
param availability string
param avdObjectId string
param locationControlPlane string
param dataCollectionRulesName string
param diskNamePrefix string
param diskEncryptionOptions object
param diskEncryptionSetName string
param diskSku string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param environmentShortName string
param fslogix bool
param fslogixStorageService string
param globalFeedWorkspaceResourceGroupName string
param globalFeedWorkspaceName string
param hostPoolType string
param kerberosEncryption string
param keyVaultName string
param keyVaultPrivateDnsZoneResourceId string
param privateEndpointSubnetResourceId string
param locationVirtualMachines string
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRetention int
param logAnalyticsWorkspaceSku string
param monitoring bool
param networkInterfaceNamePrefix string
param privateEndpoint bool
param privateEndpointNameConv string
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupManagement string
param resourceGroupStorage string
param roleDefinitions object
param scalingTool bool
param sessionHostCount int
param fslogixStorageSolution string
param tags object
param timeStamp string
param timeZone string
param userAssignedIdentityNameConv string
param virtualMachineMonitoringAgent string
param virtualMachineNamePrefix string
@secure()
param virtualMachineAdminPassword string
@secure()
param virtualMachineAdminUserName string
param virtualMachineSize string
param virtualMachineSubnetResourceId string
param workspaceName string

var cpuCountMax = contains(hostPoolType, 'Pooled') ? 32 : 128
var cpuCountMin = contains(hostPoolType, 'Pooled') ? 4 : 2

var artifactsUserAssignedIdentityName = replace(userAssignedIdentityNameConv, 'uaiPurpose', 'artifacts')
var deploymentUserAssignedIdentityName = replace(userAssignedIdentityNameConv, 'uaiPurpose', 'deployment')

var virtualNetworkName = split(virtualMachineSubnetResourceId, '/')[8]
var virtualNetworkResourceGroupName = split(virtualMachineSubnetResourceId, '/')[4]

var defaultValidationParameters = '-cpuCountMax ${cpuCountMax} -cpuCountMin ${cpuCountMin} -environmentShortName ${environment().name} -globalWorkspaceName ${globalFeedWorkspaceName} -globalWorkspaceResourceName ${globalFeedWorkspaceResourceGroupName} -location ${locationVirtualMachines} -sessionHostCount ${sessionHostCount} -fslogixStorageSolution ${fslogixStorageSolution} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -userAssignedIdentityClientId ${deploymentUserAssignedIdentity.outputs.clientId} -virtualMachineSize ${virtualMachineSize} -virtualNetworkName ${virtualNetworkName} -virtualNetworkResourceGroupName ${virtualNetworkResourceGroupName} -workspaceName ${workspaceName} -WorkspaceResourceGroupName ${resourceGroupManagement}'
var validationScriptParameters = activeDirectorySolution == 'AzureActiveDirectoryDomainServices' ? '-domainName ${domainName} -kerberosEncryption ${kerberosEncryption} ${defaultValidationParameters}' : defaultValidationParameters

var roleAssignmentsCommon = [
  {
    roleDefinitionId: roleDefinitions.AutomationContributor // (Purpose: adds runbook to automation account)
    roleShortName: 'AutomationContributor'
    resourceGroup: resourceGroupManagement
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.DesktopVirtualizationApplicationGroupContributor // (Purpose: updates the friendly name for the desktop)
    roleShortName: 'AVDAppGroupContributor' 
    resourceGroup: resourceGroupManagement
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.DesktopVirtualizationSessionHostOperator // (Purpose: sets drain mode on the AVD session hosts)
    roleShortName: 'AVDSessionHostOperator'
    resourceGroup: resourceGroupManagement
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.DesktopVirtualizationWorkspaceContributor // (Purpose: update the app group references on an existing feed workspace)
    roleShortName: 'AVDWorkspaceContributor'
    resourceGroup: resourceGroupManagement
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.VirtualMachineContributor // (Purpose: remove the management virtual machine)
    roleShortName: 'VirtualMachineContributor'
    resourceGroup: resourceGroupManagement
    subscription: subscription().subscriptionId
  }
]
var roleAssignmentStorage = fslogix ? [
  {
    roleDefinitionId: roleDefinitions.StorageAccountContributor // (Purpose: domain join storage account & set NTFS permissions on the file share)
    roleShortName: 'StorageAccountContributor'
    resourceGroup: resourceGroupStorage
    subscription: subscription().subscriptionId
  }
] : []
var roleAssignments = union(roleAssignmentsCommon, roleAssignmentStorage)
var artifactsUserAssignedIdentityClientId = empty(artifactsUserAssignedIdentityResourceId) ? artifactsUserAssignedIdentity.outputs.clientId : existingArtifactsUserAssignedIdentity.properties.clientId

// Role Assignment required for Start VM On Connect
resource roleAssignment_PowerOnContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(avdObjectId, roleDefinitions.DesktopVirtualizationPowerOnContributor, subscription().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.DesktopVirtualizationPowerOnContributor)
    principalId: avdObjectId
  }
}

module deploymentUserAssignedIdentity 'userAssignedIdentity.bicep' = {
  scope: resourceGroup(resourceGroupManagement)
  name: 'UserAssignedIdentity_Deployment_${timeStamp}'
  params: {
    location: locationVirtualMachines
    name: deploymentUserAssignedIdentityName
    tags: contains(tags, 'Microsoft.ManagedIdentity/userAssignedIdentities') ? tags['Microsoft.ManagedIdentity/userAssignedIdentities'] : {}
  }
}

module roleAssignments_deployment '../roleAssignment.bicep' = [for i in range(0, length(roleAssignments)): {
  scope: resourceGroup(roleAssignments[i].subscription, roleAssignments[i].resourceGroup)
  name: 'RoleAssignment_${roleAssignments[i].roleShortName}_${timeStamp}'
  params: {
    PrincipalId: deploymentUserAssignedIdentity.outputs.principalId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: roleAssignments[i].roleDefinitionId
  }
}]

// Role Assignment for Validation
// This role assignment is required to collect validation information
resource roleAssignment_validation 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(deploymentUserAssignedIdentityName, roleDefinitions.Reader, subscription().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.Reader)
    principalId: deploymentUserAssignedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

resource existingArtifactsUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if(!empty(artifactsUserAssignedIdentityResourceId)) {
  name: last(split(artifactsUserAssignedIdentityResourceId, '/'))
  scope: resourceGroup(split(artifactsUserAssignedIdentityResourceId, '/')[2], split(artifactsUserAssignedIdentityResourceId, '/')[4])
}

module artifactsUserAssignedIdentity 'userAssignedIdentity.bicep' = if(empty(artifactsUserAssignedIdentityResourceId)) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'UserAssignedIdentity_Artifacts_${timeStamp}'
  params: {
    location: locationControlPlane
    name: artifactsUserAssignedIdentityName
    tags: contains(tags, 'Microsoft.ManagedIdentity/userAssignedIdentities') ? tags['Microsoft.ManagedIdentity/userAssignedIdentities'] : {}
  }
}
module artifactsRoleAssignment 'artifactsRoleAssignment.bicep' = if(empty(artifactsUserAssignedIdentityResourceId)) {
  scope: resourceGroup(split(artifactsStorageAccountResourceId, '/')[4], split(artifactsStorageAccountResourceId, '/')[8])
  name: 'RoleAssignment_StorageBlobReader_${timeStamp}'
  params: {
    roleDefinitionId: roleDefinitions.StorageBlobDataReader
    storageName: last(split(artifactsStorageAccountResourceId, '/'))
    userAssignedIdentityName: artifactsUserAssignedIdentityName
    userAssignedIdentityPrincipalId: artifactsUserAssignedIdentity.outputs.principalId
  }
}

module keyVault 'keyVault.bicep' =  {
  name: 'KeyVault_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName   
    environmentShortName: environmentShortName
    keyVaultName: keyVaultName
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    location: locationVirtualMachines
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointSubnetId: privateEndpointSubnetResourceId
    tagsKeyVault: contains(tags, 'Microsoft.KeyVault/vaults') ? tags['Microsoft.KeyVault/vaults'] : {}
    tagsPrivateEndpoints: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineAdminUserName: virtualMachineAdminUserName
  }
}

resource keyVault_Ref 'Microsoft.KeyVault/vaults@2023-07-01' existing = if(contains(activeDirectorySolution,'DomainServices') && (empty(domainJoinUserPassword) || empty(domainJoinUserPrincipalName)) || empty(virtualMachineAdminPassword) || empty(virtualMachineAdminUserName)) {
  name: keyVaultName
  scope: resourceGroup(resourceGroupManagement)
}

module customerManagedKeys 'customerManagedKeys.bicep' = if (diskEncryptionOptions.diskEncryptionSet || diskEncryptionOptions.keyEncryptionKey) {
  name: 'CustomerManagedKeys_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    diskEncryptionOptions: diskEncryptionOptions
    location: locationVirtualMachines
    tags: tags
    timeStamp: timeStamp
    keyVaultResourceId: keyVault.outputs.keyVaultResourceId
    userAssignedIdentityNameConv: userAssignedIdentityNameConv
  }
}

module diskEncryptionSet 'diskEncryptionSet.bicep' = if(diskEncryptionOptions.diskEncryptionSet) {
  name: 'DiskEncryptionSet_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    diskEncryptionSetName: diskEncryptionSetName
    keyUrl: customerManagedKeys.outputs.keyUriWithVersion
    keyVaultResourceId: keyVault.outputs.keyVaultResourceId
    location: locationVirtualMachines
    tags: contains(tags, 'Microsoft.Compute/diskEncryptionSets') ? tags['Microsoft.Compute/diskEncryptionSets'] : {}    
    userAssignedIdentityResourceId: customerManagedKeys.outputs.encryptionUserAssignedIdentityResourceId
  }
}

// Management VM
// The management VM is required to validate the deployment and configure FSLogix storage.
module virtualMachine 'virtualMachine.bicep' = {
  name: 'ManagementVirtualMachine_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    activeDirectorySolution: activeDirectorySolution
    artifactsUri: artifactsUri
    diskEncryptionOptions: diskEncryptionOptions
    diskEncryptionSetResourceId: diskEncryptionOptions.diskEncryptionSet ? diskEncryptionSet.outputs.resourceId : ''
    diskNamePrefix: diskNamePrefix
    diskSku: diskSku
    domainJoinUserPassword: !empty(domainJoinUserPassword) ? domainJoinUserPassword : contains(activeDirectorySolution, 'DomainServices') ? keyVault_Ref.getSecret('domainJoinUserPassword') : ''
    domainJoinUserPrincipalName: !empty(domainJoinUserPrincipalName) ? domainJoinUserPrincipalName : contains(activeDirectorySolution, 'DomainServices') ? keyVault_Ref.getSecret('domainJoinUserPrincipalName') : ''
    domainName: domainName
    location: locationVirtualMachines
    networkInterfaceNamePrefix: networkInterfaceNamePrefix
    subnet: split(virtualMachineSubnetResourceId, '/')[10]
    tagsNetworkInterfaces: contains(tags, 'Microsoft.Network/networkInterfaces') ? tags['Microsoft.Network/networkInterfaces'] : {}
    tagsVirtualMachines: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    UserAssignedIdentityResourceIds: empty(artifactsUserAssignedIdentityResourceId) ? {
      '${artifactsUserAssignedIdentity.outputs.resourceId}' : {}
      '${deploymentUserAssignedIdentity.outputs.resourceId}' : {}
     } : {
      '${existingArtifactsUserAssignedIdentity.id}': {}
      '${deploymentUserAssignedIdentity.outputs.resourceId}' : {}
     }
    virtualNetwork: virtualNetworkName
    virtualNetworkResourceGroup: virtualNetworkResourceGroupName
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineAdminUserName: virtualMachineAdminUserName
  }
}

// Deployment Validations
// This module validates the selected parameter values and collects required data
module validations 'customScriptExtensions.bicep' = {
  scope: resourceGroup(resourceGroupManagement)
  name: 'Validations_${timeStamp}'
  params: {
    artifactsUri: artifactsUri
    executeScript: 'Get-Validations.ps1'
    files: ['Get-Validations.ps1']
    location: locationVirtualMachines
    output: true
    parameters: validationScriptParameters
    tags: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: virtualMachine.outputs.Name
  }
}

// monitoring Resources for AVD Insights
// This module deploys a Log Analytics Workspace and if monitoring agent is the legacy Log Analytics Agent then the Windows Events & Windows Performance Counters plus diagnostic settings on the required resources 
module logAnalyticsWorkspace 'logAnalyticsWorkspace.bicep' = if (monitoring) {
  name: 'LogAnalytics_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRetention: logAnalyticsWorkspaceRetention
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: locationControlPlane
    tags: contains(tags, 'Microsoft.OperationalInsights/workspaces') ? tags['Microsoft.OperationalInsights/workspaces'] : {}
    virtualMachineMonitoringAgent: virtualMachineMonitoringAgent
  }
}

// Data Collection Rule for AVD Insights required for the Azure Monitor Agent
module dataCollectionRules 'avdInsightsDataCollectionRules.bicep' = if (virtualMachineMonitoringAgent == 'AzureMonitorAgent') {
  name: 'DataCollectionRule_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    LogAWorkspaceId: logAnalyticsWorkspace.outputs.ResourceId
    location: locationControlPlane
    Name: dataCollectionRulesName
    tags: contains(tags, 'Microsoft.Insights/dataCollectionRules') ? tags['Microsoft.Insights/dataCollectionRules'] : {}
  }
}

// Automation Account required for the AVD Scaling Tool and the Auto Increase Premium File Share Quota solution
module automationAccount 'automationAccount.bicep' = if (scalingTool || fslogixStorageService == 'AzureFiles Premium') {
  name: 'AutomationAccount_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    automationAccountName: automationAccountName
    location: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: monitoring ? logAnalyticsWorkspace.outputs.ResourceId : ''
    monitoring: monitoring
    tags: contains(tags, 'Microsoft.Automation/automationAccounts') ? tags['Microsoft.Automation/automationAccounts'] : {}
    automationAccountPrivateDnsZoneResourceId: automationAccountPrivateDnsZoneResourceId
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    subnetResourceId: privateEndpointSubnetResourceId
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

module recoveryServicesVault 'recoveryServicesVault.bicep' = if (recoveryServices) {
  name: 'RecoveryServicesVault_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    fslogix: fslogix
    location: locationVirtualMachines
    recoveryServicesVaultName: recoveryServicesVaultName
    fslogixStorageSolution: fslogixStorageSolution
    tags: contains(tags, 'Microsoft.recoveryServices/vaults') ? tags['Microsoft.recoveryServices/vaults'] : {}
    timeZone: timeZone
  }
}

/*
module workspace 'workspace.bicep' = {
  name: 'Workspace_Create_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    applicationGroupReferences: []
    Existing: validations.outputs.value.existingWorkspace == 'true' ? true : false
    friendlyName: workspaceFriendlyName
    location: locationControlPlane
    logAnalyticsWorkspaceResourceId: monitoring ? logAnalyticsWorkspace.outputs.ResourceId : ''
    monitoring: monitoring
    tags: contains(tags, 'Microsoft.DesktopVirtualization/workspaces') ? tags['Microsoft.DesktopVirtualization/workspaces'] : {}
    timeStamp: timeStamp
    workspaceName: workspaceName
  }
}
*/

output artifactsUserAssignedIdentityClientId string = artifactsUserAssignedIdentityClientId
output artifactsUserAssignedIdentityResourceId string = empty(artifactsUserAssignedIdentityResourceId) ? artifactsUserAssignedIdentity.outputs.resourceId : existingArtifactsUserAssignedIdentity.id
output encryptionKeyUrl string = customerManagedKeys.outputs.keyUri
output existingWorkspace bool = validations.outputs.value.existingWorkspace == 'true' ? true : false
output existingGlobalWorkspace bool = validations.outputs.value.existingGlobalWorkspace == 'true' ? true : false
output keyVaultResourceId string = keyVault.outputs.keyVaultResourceId
output keyVaultUrl string = keyVault.outputs.keyVaultUrl
output dataCollectionRulesResourceId string = virtualMachineMonitoringAgent == 'AzureMonitorAgent' ? dataCollectionRules.outputs.dataCollectionRulesId : ''
output diskEncryptionSetResourceId string = diskEncryptionOptions.diskEncryptionSet ? diskEncryptionSet.outputs.resourceId : ''
output logAnalyticsWorkspaceResourceId string = monitoring ? logAnalyticsWorkspace.outputs.ResourceId : ''
output deploymentUserAssignedIdentityClientId string = deploymentUserAssignedIdentity.outputs.clientId
output deploymentUserAssignedIdentityResourceId string = deploymentUserAssignedIdentity.outputs.resourceId
output validateAcceleratedNetworking string = validations.outputs.value.acceleratedNetworking
output validateANFfActiveDirectory string = validations.outputs.value.anfActiveDirectory
output validateANFDnsServers string = validations.outputs.value.anfDnsServers
output validateANFSubnetId string = validations.outputs.value.anfSubnetId
output validateavailabilityZones array = availability == 'availabilityZones' ? validations.outputs.value.availabilityZones : [ '1' ]
output validateTrustedLaunch string = validations.outputs.value.trustedLaunch
output virtualMachineName string = virtualMachine.outputs.Name