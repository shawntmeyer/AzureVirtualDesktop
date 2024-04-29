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
param deployScalingPlan bool
//param diskAccessName string
param diskEncryptionSetNames object
param diskSku string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param enableIncreaseQuotaAutomation bool
param encryptionAtHost bool
param environmentShortName string
param fslogix bool
param fslogixStorageAccountNamePrefix string
param fslogixStorageService string
param fslogixStorageSolution string
param globalFeedWorkspaceResourceGroupName string
param globalFeedWorkspaceName string
param hostPoolType string
param kerberosEncryption string
param keyVaultNames object
param keyVaultPrivateDnsZoneResourceId string
param privateEndpointSubnetResourceId string
param locationVirtualMachines string
param logAnalyticsWorkspaceResourceId string
param enableMonitoring bool
param netAppVnetResourceId string
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
param securityType string
param sessionHostCount int
param tags object
param timeStamp string
param timeZone string
param userAssignedIdentityNameConv string
param virtualMachineName string
param virtualMachineNICName string
param virtualMachineDiskName string
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
var deploymentUserAssignedIdentityName = replace(userAssignedIdentityNameConv, 'uaiPurpose', 'avd-deployment')

var confidentialVMOSDiskEncryption = confidentialVMOSDiskEncryptionType == 'DiskWithVMGuestState' ? true : false
var diskEncryptionSetEncryptionType = confidentialVMOSDiskEncryption ? 'ConfidentialVmEncryptedWithCustomerKey' : ( keyManagementDisksAndStorage == 'CustomerManaged' ? 'EncryptionAtRestWithCustomerKey' : 'EncryptionAtRestWithPlatformAndCustomerKeys' )

var netAppVirtualNetworkName = !empty(netAppVnetResourceId) ? (split(netAppVnetResourceId, '/')) : ''
var netAppVirtualNetworkResourceGroupName = !empty(netAppVnetResourceId) ? split(netAppVnetResourceId, '/')[4] : ''

var requiredValidationScriptParameters = '-ActiveDirectorySolution ${identitySolution} -CpuCountMax ${cpuCountMax} -CpuCountMin ${cpuCountMin} -Environment ${environment().name} -GlobalWorkspaceName ${globalFeedWorkspaceName} -GlobalWorkspaceResourceGroupName ${globalFeedWorkspaceResourceGroupName} -Location ${locationVirtualMachines} -SessionHostCount ${sessionHostCount} -StorageAccountPrefix ${fslogixStorageAccountNamePrefix} -StorageSolution ${fslogixStorageSolution} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${deploymentUserAssignedIdentity.outputs.clientId} -VirtualMachineSize ${virtualMachineSize} -WorkspaceName ${workspaceName} -WorkspaceResourceGroupName ${resourceGroupControlPlane}'
var netAppValidationScriptParameters = '-NetAppVirtualNetworkName ${netAppVirtualNetworkName} -NetAppVirtualNetworkResourceGroupName ${netAppVirtualNetworkResourceGroupName}'
var domainServicesValidationScriptParameters = '-DomainName ${domainName} -KerberosEncryption ${kerberosEncryption}'
var optionalValidationScriptParameters = identitySolution == 'EntraDomainServices' ? ( contains(fslogixStorageSolution, 'NetApp') ? '${domainServicesValidationScriptParameters} ${netAppValidationScriptParameters}' : domainServicesValidationScriptParameters ) : ( contains(fslogixStorageSolution, 'NetApp') ? netAppValidationScriptParameters : '' )
var validationScriptParameters = empty(securityType) ? replace('${requiredValidationScriptParameters} ${optionalValidationScriptParameters}', '  ', ' ') : replace('${requiredValidationScriptParameters} ${optionalValidationScriptParameters} -SecurityType ${securityType}', '  ', ' ')

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
var roleAssignmentKeyVault = confidentialVMOSDiskEncryption && keyManagementDisksAndStorage == 'CustomerManaged' ? [
  {
    roleDefinitionId: roleDefinitions.KeyVaultReader // (Purpose: Retrieve the customer managed keys from the key vault for idempotent deployment)
    roleShortName: 'KeyVaultReader'
    resourceGroup: resourceGroupManagement
    subscription: subscription().subscriptionId
  }
] : []

var roleAssignments = union(roleAssignmentsCommon, roleAssignmentKeyVault, roleAssignmentStorage)
var artifactsUserAssignedIdentityClientId = empty(artifactsUserAssignedIdentityResourceId) ? artifactsUserAssignedIdentity.outputs.clientId : existingArtifactsUserAssignedIdentity.properties.clientId

// Role Assignment required for Start VM On Connect
resource roleAssignment_PowerOnContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(avdObjectId, roleDefinitions.DesktopVirtualizationPowerOnContributor, subscription().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.DesktopVirtualizationPowerOnContributor)
    principalId: avdObjectId
  }
}

// Role Assignment required for Scaling Plans
resource roleAssignment_PowerOnOffContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(deployScalingPlan) {
  name: guid(avdObjectId, roleDefinitions.DesktopVirtualizationPowerOnOffContributor, subscription().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.DesktopVirtualizationPowerOnOffContributor)
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

module roleAssignments_deployment '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = [for i in range(0, length(roleAssignments)): {
  scope: resourceGroup(roleAssignments[i].subscription, roleAssignments[i].resourceGroup)
  name: 'RoleAssignment_${roleAssignments[i].roleShortName}_${timeStamp}'
  params: {
    principalId: deploymentUserAssignedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleAssignments[i].roleDefinitionId
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
  scope: resourceGroup(split(artifactsStorageAccountResourceId, '/')[2], split(artifactsStorageAccountResourceId, '/')[4])
  name: 'RoleAssignment_StorageBlobReader_${timeStamp}'
  params: {
    roleDefinitionId: roleDefinitions.StorageBlobDataReader
    storageName: last(split(artifactsStorageAccountResourceId, '/'))
    userAssignedIdentityName: artifactsUserAssignedIdentityName
    userAssignedIdentityPrincipalId: empty(artifactsUserAssignedIdentityResourceId) ? artifactsUserAssignedIdentity.outputs.principalId : ''
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
module policy 'policy.bicep' = if (contains(hostPoolType, 'Pooled') || recoveryServices) {
  name: 'ManagedDisks_NetworkAccess_Policy_${timeStamp}'
  params: {
    // Disabling the param below until Enhanced Policies in Recovery Services support managed disks with private link
    //diskAccessResourceId: diskAccess.outputs.resourceId
    location: locationVirtualMachines
    resourceGroupName: resourceGroupHosts
  }
}

resource keyVault_Ref 'Microsoft.KeyVault/vaults@2023-07-01' existing = if(contains(identitySolution,'DomainServices') && (empty(domainJoinUserPassword) || empty(domainJoinUserPrincipalName)) || empty(virtualMachineAdminPassword) || empty(virtualMachineAdminUserName)) {
  name: keyVaultNames.VMSecrets
  scope: resourceGroup(resourceGroupManagement)
}

module secretsKeyVault 'keyVault.bicep' = if(!empty(virtualMachineAdminPassword) || !empty(virtualMachineAdminUserName) || !empty(domainJoinUserPassword) || !empty(domainJoinUserPrincipalName)) {
  name: 'KeyVault_Secrets_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: false   
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

// Management VM
// The management VM is required to validate the deployment and configure FSLogix storage. This deployment does not use customer managed keys for the management machine to allow it to remain idempotent.
module virtualMachine 'virtualMachine.bicep' = {
  name: 'ManagementVirtualMachine_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    identitySolution: identitySolution
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    azModuleBlobName: azModuleBlobName
    diskName: virtualMachineDiskName
    diskSku: diskSku
    domainJoinUserPassword: !contains(identitySolution, 'DomainServices') ? '' : !empty(domainJoinUserPassword) ? domainJoinUserPassword : keyVault_Ref.getSecret('domainJoinUserPassword')
    domainJoinUserPrincipalName: !contains(identitySolution, 'DomainServices') ? '' : !empty(domainJoinUserPrincipalName) ? domainJoinUserPrincipalName : keyVault_Ref.getSecret('domainJoinUserPrincipalName')
    domainName: domainName
    encryptionAtHost: encryptionAtHost
    location: locationVirtualMachines
    networkInterfaceName: virtualMachineNICName
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
    virtualMachineName: virtualMachineName
    virtualMachineAdminPassword: !empty(virtualMachineAdminPassword) ? virtualMachineAdminPassword : keyVault_Ref.getSecret('virtualMachineAdminPassword')
    virtualMachineAdminUserName: !empty(virtualMachineAdminUserName) ? virtualMachineAdminUserName : keyVault_Ref.getSecret('virtualMachineAdminUserName')
  }
}

// Deployment Validations
// This module validates the selected parameter values and collects required data
module validations '../../../sharedModules/custom/customScriptExtension.bicep' = {
  scope: resourceGroup(resourceGroupManagement)
  name: 'Validations_${timeStamp}'
  params: {
    artifactsLocation: artifactsUri
    files: [
      'Get-Validations.ps1'
    ]
    powerShellScriptName: 'Get-Validations.ps1'
    location: locationVirtualMachines
    scriptParameters: validationScriptParameters
    tags: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: virtualMachine.outputs.Name
  }
  dependsOn: [
    roleAssignments_deployment
    roleAssignment_validation
  ]
}

module customerManagedKeys 'customerManagedKeys.bicep' = if (keyManagementDisksAndStorage != 'PlatformManaged') {
  name: 'CustomerManagedKeys_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    confidentialVMOrchestratorObjectId: confidentialVMOrchestratorObjectId
    confidentialVMOSDiskEncryption: confidentialVMOSDiskEncryption
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentity.outputs.clientId
    diskEncryptionSetEncryptionType: diskEncryptionSetEncryptionType
    diskEncryptionSetNames: diskEncryptionSetNames
    keyVaultNames: keyVaultNames
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    environmentShortName: environmentShortName
    location: locationVirtualMachines
    managementVirtualMachineName: virtualMachine.outputs.Name
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointSubnetId: privateEndpointSubnetResourceId
    tags: tags
    timeStamp: timeStamp
    userAssignedIdentityNameConv: userAssignedIdentityNameConv
  }
  dependsOn: [
    validations
  ]
}


// Automation Account required for the Auto Increase Premium File Share Quota solution
module automationAccount 'automationAccount.bicep' = if (enableIncreaseQuotaAutomation && fslogixStorageService == 'AzureFiles Premium') {
  name: 'AutomationAccount_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    automationAccountName: automationAccountName
    location: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: enableMonitoring ? logAnalyticsWorkspaceResourceId : ''
    enableMonitoring: enableMonitoring
    tags: tags
    automationAccountPrivateDnsZoneResourceId: automationAccountPrivateDnsZoneResourceId
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    subnetResourceId: privateEndpointSubnetResourceId
    virtualMachineName: virtualMachine.outputs.Name
  }
}

module recoveryServicesVault 'recoveryServicesVault.bicep' = if (recoveryServices) {
  name: 'RecoveryServicesVault_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    fslogix: fslogix
    hostPoolType: hostPoolType
    location: locationVirtualMachines
    recoveryServicesVaultName: recoveryServicesVaultName
    fslogixStorageSolution: fslogixStorageSolution
    tags: tags
    timeZone: timeZone
  }
}

output artifactsUserAssignedIdentityClientId string = artifactsUserAssignedIdentityClientId
output artifactsUserAssignedIdentityResourceId string = empty(artifactsUserAssignedIdentityResourceId) ? artifactsUserAssignedIdentity.outputs.resourceId : existingArtifactsUserAssignedIdentity.id
output diskEncryptionSetResourceId string = keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.diskEncryptionSetResourceId : ''
output encryptionUserAssignedIdentityResourceId string = keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.encryptionUserAssignedIdentityResourceId : ''
output existingWorkspace bool = validations.outputs.value.existingWorkspace == 'true' ? true : false
output existingGlobalWorkspace bool = validations.outputs.value.existingGlobalWorkspace == 'true' ? true : false
output storageEncryptionKeyKeyVaultUri string = keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.storagestorageEncryptionKeyKeyVaultUri : ''
output deploymentUserAssignedIdentityClientId string = deploymentUserAssignedIdentity.outputs.clientId
output deploymentUserAssignedIdentityResourceId string = deploymentUserAssignedIdentity.outputs.resourceId
output storageAccountEncryptionKeyName string = keyManagementDisksAndStorage != 'PlatformManaged' ? customerManagedKeys.outputs.storageKeyName : ''
output validateAcceleratedNetworking string = validations.outputs.value.acceleratedNetworking
output validateANFfActiveDirectory string = validations.outputs.value.anfActiveDirectory
output validateANFDnsServers string = validations.outputs.value.anfDnsServers
output validateANFSubnetId string = validations.outputs.value.anfSubnetId
output validateavailabilityZones array = availability == 'availabilityZones' ? validations.outputs.value.availabilityZones : [ '1' ]
output virtualMachineName string = virtualMachine.outputs.Name
