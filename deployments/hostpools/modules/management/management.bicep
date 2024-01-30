targetScope = 'subscription'
param identitySolution string
param artifactsUri string
param artifactsStorageAccountResourceId string
param artifactsUserAssignedIdentityResourceId string
param automationAccountName string
param automationAccountPrivateDnsZoneResourceId string
param availability string
param avdObjectId string
param azModuleBlobName string
param locationControlPlane string
param confidentialVMOrchestratorObjectId string
param confidentialVMOSDiskEncryptionType string
param dataCollectionEndpointName string
param dataCollectionRulesNameConv string
//param diskAccessName string
param diskNamePrefix string
param diskEncryptionSetNames object
param diskSku string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param encryptionAtHost bool
param environmentShortName string
param fslogix bool
param fslogixStorageService string
param globalFeedWorkspaceResourceGroupName string
param globalFeedWorkspaceName string
param hostPoolType string
param kerberosEncryption string
param keyVaultNames object
param keyVaultPrivateDnsZoneResourceId string
param privateEndpointSubnetResourceId string
param locationVirtualMachines string
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRetention int
param logAnalyticsWorkspaceSku string
param enableInsights bool
param netAppVnetResourceId string
param networkInterfaceNamePrefix string
param keyManagementDisksAndStorage string
param privateEndpoint bool
param privateEndpointNameConv string
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupControlPlane string
param resourceGroupHosts string
param resourceGroupManagement string
param resourceGroupStorage string
param roleDefinitions object
param securityDataCollectionRulesResourceId string
param securityType string
param sessionHostCount int
param fslogixStorageAccountNamePrefix string
param fslogixStorageSolution string
param tags object
param timeStamp string
param timeZone string
param userAssignedIdentityNameConv string
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

var confidentialVMOSDiskEncryption = confidentialVMOSDiskEncryptionType == 'DiskWithVMGuestState' ? true : false
var diskEncryptionSetEncryptionType = confidentialVMOSDiskEncryption ? 'ConfidentialVmEncryptedWithCustomerKey' : ( keyManagementDisksAndStorage == 'CustomerManaged' ? 'EncryptionAtRestWithCustomerKey' : 'EncryptionAtRestWithPlatformAndCustomerKeys' )

var netAppVirtualNetworkName = !empty(netAppVnetResourceId) ? (split(netAppVnetResourceId, '/')) : ''
var netAppVirtualNetworkResourceGroupName = !empty(netAppVnetResourceId) ? split(netAppVnetResourceId, '/')[4] : ''

var requiredValidationScriptParameters = '-ActiveDirectorySolution ${identitySolution} -CpuCountMax ${cpuCountMax} -CpuCountMin ${cpuCountMin} -Environment ${environment().name} -GlobalWorkspaceName ${globalFeedWorkspaceName} -GlobalWorkspaceResourceGroupName ${globalFeedWorkspaceResourceGroupName} -Location ${locationVirtualMachines} -SessionHostCount ${sessionHostCount} -StorageAccountPrefix ${fslogixStorageAccountNamePrefix} -StorageSolution ${fslogixStorageSolution} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${deploymentUserAssignedIdentity.outputs.clientId} -VirtualMachineSize ${virtualMachineSize} -WorkspaceName ${workspaceName} -WorkspaceResourceGroupName ${resourceGroupControlPlane}'
var netAppValidationScriptParameters = '-NetAppVirtualNetworkName ${netAppVirtualNetworkName} -NetAppVirtualNetworkResourceGroupName ${netAppVirtualNetworkResourceGroupName}'
var domainServicesValidationScriptParameters = '-DomainName ${domainName} -KerberosEncryption ${kerberosEncryption}'
var optionalValidationScriptParameters = identitySolution == 'EntraDomainServices' ? ( contains(fslogixStorageSolution, 'NetApp') ? '${domainServicesValidationScriptParameters} ${netAppValidationScriptParameters}' : domainServicesValidationScriptParameters ) : ( contains(fslogixStorageSolution, 'NetApp') ? netAppValidationScriptParameters : '' )
var validationScriptParameters = empty(securityType) ? '${requiredValidationScriptParameters} ${optionalValidationScriptParameters}' : '${requiredValidationScriptParameters} ${optionalValidationScriptParameters} -SecurityType ${securityType}'

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
    resourceGroup: resourceGroupControlPlane
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.DesktopVirtualizationSessionHostOperator // (Purpose: sets drain mode on the AVD session hosts)
    roleShortName: 'AVDSessionHostOperator'
    resourceGroup: resourceGroupControlPlane
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.DesktopVirtualizationWorkspaceContributor // (Purpose: update the app group references on an existing feed workspace)
    roleShortName: 'AVDWorkspaceContributor'
    resourceGroup: resourceGroupControlPlane
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.VirtualMachineContributor // (Purpose: remove the management virtual machine)
    roleShortName: 'VirtualMachineContributor'
    resourceGroup: resourceGroupManagement
    subscription: subscription().subscriptionId
  }
]
var roleAssignmentStorage = fslogix && !contains(identitySolution, 'EntraId')? [
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

module roleAssignments_deployment '../common/roleAssignment.bicep' = [for i in range(0, length(roleAssignments)): {
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

resource keyVault_Ref 'Microsoft.KeyVault/vaults@2023-07-01' existing = if(contains(identitySolution,'DomainServices') && (empty(domainJoinUserPassword) || empty(domainJoinUserPrincipalName)) || empty(virtualMachineAdminPassword) || empty(virtualMachineAdminUserName)) {
  name: keyVaultNames.VMSecrets
  scope: resourceGroup(resourceGroupManagement)
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
    userAssignedIdentityPrincipalId: empty(artifactsUserAssignedIdentityResourceId)? artifactsUserAssignedIdentity.outputs.principalId : ''
  }
}

// Disabling the deployment below until Enhanced Policies in Recovery Services support managed disks with private link
/*
module diskAccess 'diskAccess.bicep' = {
  scope: resourceGroup(resourceGroupManagement)
  name: 'DiskAccess_${timeStamp}'
  params: {
    diskAccessName: diskAccessName
    location: locationVirtualMachines
    privateEndpointNameConv: privateEndpointNameConv
    subnetResourceId: privateEndpointSubnetResourceId
    tags: tags
  }
}
*/

// Sets an Azure policy to disable public network access to managed disks
// Once Enhanced Policies in Recovery Services support managed disks with private link, remove the "if" condition
module policy 'policy.bicep' = if (contains(hostPoolType, 'Pooled') && recoveryServices) {
  name: 'ManagedDisks_NetworkAccess_Policy_${timeStamp}'
  params: {
    // Disabling the param below until Enhanced Policies in Recovery Services support managed disks with private link
    //diskAccessResourceId: diskAccess.outputs.resourceId
    location: locationVirtualMachines
    resourceGroupName: resourceGroupHosts
  }
}

module secretsKeyVault 'keyVault.bicep' =  {
  name: 'KeyVault_Secrets_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName   
    environmentShortName: environmentShortName
    keyVaultName: keyVaultNames.VMSecrets
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    location: locationVirtualMachines
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointSubnetId: privateEndpointSubnetResourceId
    skuName: 'standard'
    tagsKeyVault: contains(tags, 'Microsoft.KeyVault/vaults') ? tags['Microsoft.KeyVault/vaults'] : {}
    tagsPrivateEndpoints: contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {}
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineAdminUserName: virtualMachineAdminUserName
  }
}

module customerManagedKeys 'customerManagedKeys.bicep' = if (keyManagementDisksAndStorage != 'PlatformManaged') {
  name: 'CustomerManagedKeys_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    confidentialVMOrchestratorObjectId: confidentialVMOrchestratorObjectId
    confidentialVMOSDiskEncryption: confidentialVMOSDiskEncryption
    diskEncryptionSetEncryptionType: diskEncryptionSetEncryptionType
    diskEncryptionSetNames: diskEncryptionSetNames
    keyVaultNames: keyVaultNames
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    environmentShortName: environmentShortName
    location: locationVirtualMachines
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointSubnetId: privateEndpointSubnetResourceId
    userAssignedIdentityNameConv: userAssignedIdentityNameConv
    tags: tags
    timeStamp: timeStamp
  }
}

// Management VM
// The management VM is required to validate the deployment and configure FSLogix storage.
module virtualMachine 'virtualMachine.bicep' = {
  name: 'ManagementVirtualMachine_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    identitySolution: identitySolution
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    azModuleBlobName: azModuleBlobName
    diskEncryptionSetResourceId: keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.diskEncryptionSetResourceId : ''
    diskNamePrefix: diskNamePrefix
    diskSku: diskSku
    domainJoinUserPassword: !empty(domainJoinUserPassword) ? domainJoinUserPassword : contains(identitySolution, 'DomainServices') ? keyVault_Ref.getSecret('domainJoinUserPassword') : ''
    domainJoinUserPrincipalName: !empty(domainJoinUserPrincipalName) ? domainJoinUserPrincipalName : contains(identitySolution, 'DomainServices') ? keyVault_Ref.getSecret('domainJoinUserPrincipalName') : ''
    domainName: domainName
    encryptionAtHost: encryptionAtHost
    location: locationVirtualMachines
    networkInterfaceNamePrefix: networkInterfaceNamePrefix
    confidentialVMOSDiskEncryptionType: confidentialVMOSDiskEncryptionType 
    securityType: securityType
    subnetResourceId: virtualMachineSubnetResourceId
    tagsNetworkInterfaces: contains(tags, 'Microsoft.Network/networkInterfaces') ? tags['Microsoft.Network/networkInterfaces'] : {}
    tagsVirtualMachines: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}
    userAssignedIdentitiesResourceIds: empty(artifactsUserAssignedIdentityResourceId) ? {
      '${artifactsUserAssignedIdentity.outputs.resourceId}' : {}
      '${deploymentUserAssignedIdentity.outputs.resourceId}' : {}
     } : {
      '${existingArtifactsUserAssignedIdentity.id}': {}
      '${deploymentUserAssignedIdentity.outputs.resourceId}' : {}
     }
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineAdminUserName: virtualMachineAdminUserName
  }
}

// Deployment Validations
// This module validates the selected parameter values and collects required data
module validations '../common/customScriptExtensions.bicep' = {
  scope: resourceGroup(resourceGroupManagement)
  name: 'Validations_${timeStamp}'
  params: {
    fileUris: [
      '${artifactsUri}Get-Validations.ps1'
    ]
    scriptFileName: 'Get-Validations.ps1'
    location: locationVirtualMachines
    parameters: validationScriptParameters
    tags: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: virtualMachine.outputs.Name
  }
}

// enableInsights Resources for AVD Insights

module logAnalyticsWorkspace 'logAnalyticsWorkspace.bicep' = if (enableInsights) {
  name: 'LogAnalytics_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRetention: logAnalyticsWorkspaceRetention
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: locationControlPlane
    tags: contains(tags, 'Microsoft.OperationalInsights/workspaces') ? tags['Microsoft.OperationalInsights/workspaces'] : {}
  }
}

// Data Collection Rule for AVD Insights required for the Azure Monitor Agent
module avdInsightsDataCollectionRules 'avdInsightsDataCollectionRules.bicep' = if (enableInsights) {
  name: 'AVDInsights_DataCollectionRule_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    LogAWorkspaceId: logAnalyticsWorkspace.outputs.ResourceId
    location: locationControlPlane
    NameConv: dataCollectionRulesNameConv
    tags: contains(tags, 'Microsoft.Insights/dataCollectionRules') ? tags['Microsoft.Insights/dataCollectionRules'] : {}
  }
}

// Data Collection Rule for VM Insights required for the Azure Monitor Agent
module vmInsightsDataCollectionRules 'vmInsightsDataCollectionRules.bicep' = if (enableInsights) {
  name: 'VMInsights_DataCollectionRule_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    LogAWorkspaceId: logAnalyticsWorkspace.outputs.ResourceId
    location: locationControlPlane
    NameConv: dataCollectionRulesNameConv
    tags: contains(tags, 'Microsoft.Insights/dataCollectionRules') ? tags['Microsoft.Insights/dataCollectionRules'] : {}
  }
}

module dataCollectionEndpoint 'dataCollectionEndpoint.bicep' = if (enableInsights || !empty(securityDataCollectionRulesResourceId)) {
  name: 'DataCollectionEndpoint_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    location: locationControlPlane
    tags: contains(tags, 'Microsoft.Insights/dataCollectionEndpoints') ? tags['Microsoft.Insights/dataCollectionEndpoints'] : {}
    name: dataCollectionEndpointName
    publicNetworkAccess: 'Enabled'
  }
}

// Automation Account required for the Auto Increase Premium File Share Quota solution
module automationAccount 'automationAccount.bicep' = if (fslogixStorageService == 'AzureFiles Premium') {
  name: 'AutomationAccount_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    automationAccountName: automationAccountName
    location: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: enableInsights ? logAnalyticsWorkspace.outputs.ResourceId : ''
    enableInsights: enableInsights
    tags: tags
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

output artifactsUserAssignedIdentityClientId string = artifactsUserAssignedIdentityClientId
output artifactsUserAssignedIdentityResourceId string = empty(artifactsUserAssignedIdentityResourceId) ? artifactsUserAssignedIdentity.outputs.resourceId : existingArtifactsUserAssignedIdentity.id
output dataCollectionEndpointResourceId string = enableInsights ? dataCollectionEndpoint.outputs.resourceId : ''
output avdInsightsDataCollectionRulesResourceId string = enableInsights ? avdInsightsDataCollectionRules.outputs.dataCollectionRulesId : ''
output vmInsightsDataCollectionRulesResourceId string = enableInsights ? vmInsightsDataCollectionRules.outputs.dataCollectionRulesId : ''
output diskEncryptionKeyUrl string = keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.diskEncryptionKeyUrl : ''
output diskEncryptionSetResourceId string = keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.diskEncryptionSetResourceId : ''
output encryptionUserAssignedIdentityResourceId string = keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.encryptionUserAssignedIdentityResourceId : ''
output existingWorkspace bool = validations.outputs.value.existingWorkspace == 'true' ? true : false
output existingGlobalWorkspace bool = validations.outputs.value.existingGlobalWorkspace == 'true' ? true : false
output storageEncryptionKeyKeyVaultUri string = keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.storagestorageEncryptionKeyKeyVaultUri : ''
output logAnalyticsWorkspaceResourceId string = enableInsights ? logAnalyticsWorkspace.outputs.ResourceId : ''
output deploymentUserAssignedIdentityClientId string = deploymentUserAssignedIdentity.outputs.clientId
output deploymentUserAssignedIdentityResourceId string = deploymentUserAssignedIdentity.outputs.resourceId
output storageAccountEncryptionKeyName string = keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.storageKeyName : ''
output validateAcceleratedNetworking string = validations.outputs.value.acceleratedNetworking
output validateANFfActiveDirectory string = validations.outputs.value.anfActiveDirectory
output validateANFDnsServers string = validations.outputs.value.anfDnsServers
output validateANFSubnetId string = validations.outputs.value.anfSubnetId
output validateavailabilityZones array = availability == 'availabilityZones' ? validations.outputs.value.availabilityZones : [ '1' ]
output validateTrustedLaunch string = validations.outputs.value.trustedLaunch
output virtualMachineName string = virtualMachine.outputs.Name
