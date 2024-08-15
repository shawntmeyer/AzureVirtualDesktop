targetScope = 'subscription'
param identitySolution string
param artifactsUri string
param artifactsStorageAccountResourceId string
param artifactsUserAssignedIdentityResourceId string
param automationAccountName string
param automationAccountPrivateDnsZoneResourceId string
param azureBlobsPrivateDnsZoneResourceId string
param avdObjectId string
param azModuleBlobName string
param locationControlPlane string
param confidentialVMOrchestratorObjectId string
param confidentialVMOSDiskEncryptionType string
param deployDiskAccessPolicy bool
param deployDiskAccessResource bool
param deployScalingPlan bool
param diskAccessName string
param diskEncryptionSetNames object
param diskSku string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param enableIncreaseQuotaAutomation bool
param encryptionAtHost bool
param envShortName string
param fslogix bool
param fslogixStorageIndex int
param keyManagementFSLogixStorage string
param fslogixStorageService string
param fslogixStorageSolution string
param hostPoolType string
param keyVaultNames object
param keyVaultPrivateDnsZoneResourceId string
param privateEndpointSubnetResourceId string
param locationVirtualMachines string
param logAnalyticsWorkspaceResourceId string
param enableMonitoring bool
param keyManagementDisks string
param managementVmSize string
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupControlPlane string
param resourceGroupHosts string
param resourceGroupManagement string
param resourceGroupStorage string
param roleDefinitions object
param storageCount int
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
param virtualMachineSubnetResourceId string

var artifactsUserAssignedIdentityName = replace(userAssignedIdentityNameConv, 'UAIPURPOSE', 'artifacts')
var deploymentUserAssignedIdentityName = replace(userAssignedIdentityNameConv, 'UAIPURPOSE', 'avd-deployment')

var confidentialVMOSDiskEncryption = confidentialVMOSDiskEncryptionType == 'DiskWithVMGuestState' ? true : false
var diskEncryptionSetEncryptionType = confidentialVMOSDiskEncryption
  ? 'ConfidentialVmEncryptedWithCustomerKey'
  : (!contains(keyManagementDisks, 'Platform')
      ? 'EncryptionAtRestWithCustomerKey'
      : 'EncryptionAtRestWithPlatformAndCustomerKeys')

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
var roleAssignmentStorage = fslogix && !contains(identitySolution, 'EntraId')
  ? [
      {
        roleDefinitionId: roleDefinitions.StorageAccountContributor // (Purpose: domain join storage account & set NTFS permissions on the file share)
        roleShortName: 'StorageAccountContributor'
        resourceGroup: resourceGroupStorage
        subscription: subscription().subscriptionId
      }
    ]
  : []
var roleAssignmentKeyVault = confidentialVMOSDiskEncryption && contains(keyManagementDisks, 'CustomerManaged')
  ? [
      {
        roleDefinitionId: roleDefinitions.KeyVaultReader // (Purpose: Retrieve the customer managed keys from the key vault for idempotent deployment)
        roleShortName: 'KeyVaultReader'
        resourceGroup: resourceGroupManagement
        subscription: subscription().subscriptionId
      }
    ]
  : []

var roleAssignments = union(roleAssignmentsCommon, roleAssignmentKeyVault, roleAssignmentStorage)
var artifactsUserAssignedIdentityClientId = empty(artifactsUserAssignedIdentityResourceId)
  ? artifactsUserAssignedIdentity.outputs.clientId
  : existingArtifactsUserAssignedIdentity.properties.clientId

// Role Assignment required for Start VM On Connect
resource roleAssignment_PowerOnContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(avdObjectId, roleDefinitions.DesktopVirtualizationPowerOnContributor, subscription().id)
  properties: {
    roleDefinitionId: resourceId(
      'Microsoft.Authorization/roleDefinitions',
      roleDefinitions.DesktopVirtualizationPowerOnContributor
    )
    principalId: avdObjectId
  }
}

// Role Assignment required for Scaling Plans
resource roleAssignment_PowerOnOffContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployScalingPlan) {
  name: guid(avdObjectId, roleDefinitions.DesktopVirtualizationPowerOnOffContributor, subscription().id)
  properties: {
    roleDefinitionId: resourceId(
      'Microsoft.Authorization/roleDefinitions',
      roleDefinitions.DesktopVirtualizationPowerOnOffContributor
    )
    principalId: avdObjectId
  }
}

module deploymentUserAssignedIdentity 'userAssignedIdentity.bicep' = {
  scope: resourceGroup(resourceGroupManagement)
  name: 'UserAssignedIdentity_Deployment_${timeStamp}'
  params: {
    location: locationVirtualMachines
    name: deploymentUserAssignedIdentityName
    tags: tags[?'Microsoft.ManagedIdentity/userAssignedIdentities'] ?? {}
  }
}

module roleAssignments_deployment '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = [
  for i in range(0, length(roleAssignments)): {
    scope: resourceGroup(roleAssignments[i].subscription, roleAssignments[i].resourceGroup)
    name: 'RoleAssignment_${roleAssignments[i].roleShortName}_${timeStamp}'
    params: {
      principalId: deploymentUserAssignedIdentity.outputs.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: roleAssignments[i].roleDefinitionId
    }
  }
]

resource existingArtifactsUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (!empty(artifactsUserAssignedIdentityResourceId)) {
  name: last(split(artifactsUserAssignedIdentityResourceId, '/'))
  scope: resourceGroup(
    split(artifactsUserAssignedIdentityResourceId, '/')[2],
    split(artifactsUserAssignedIdentityResourceId, '/')[4]
  )
}

module artifactsUserAssignedIdentity 'userAssignedIdentity.bicep' = if (empty(artifactsUserAssignedIdentityResourceId)) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'UserAssignedIdentity_Artifacts_${timeStamp}'
  params: {
    location: locationControlPlane
    name: artifactsUserAssignedIdentityName
    tags: tags[?'Microsoft.ManagedIdentity/userAssignedIdentities'] ?? {}
  }
}
module artifactsRoleAssignment 'artifactsRoleAssignment.bicep' = if (empty(artifactsUserAssignedIdentityResourceId)) {
  scope: resourceGroup(
    split(artifactsStorageAccountResourceId, '/')[2],
    split(artifactsStorageAccountResourceId, '/')[4]
  )
  name: 'RoleAssignment_StorageBlobReader_${timeStamp}'
  params: {
    roleDefinitionId: roleDefinitions.StorageBlobDataReader
    storageName: last(split(artifactsStorageAccountResourceId, '/'))
    userAssignedIdentityName: artifactsUserAssignedIdentityName
    userAssignedIdentityPrincipalId: empty(artifactsUserAssignedIdentityResourceId)
      ? artifactsUserAssignedIdentity.outputs.principalId
      : ''
  }
}

module privateEndpointVnet '../common/privateEndpointVnet.bicep' = if (privateEndpoint && !empty(privateEndpointSubnetResourceId)) {
  name: 'PrivateEndpointVnet_${timeStamp}'
  params: {
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
  }
}

module diskAccess 'diskAccess.bicep' = if(deployDiskAccessResource) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'DiskAccess_${timeStamp}'
  params: {
    diskAccessName: diskAccessName
    location: locationVirtualMachines
    privateDNSZoneResourceId: azureBlobsPrivateDnsZoneResourceId
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    privateEndpointLocation: privateEndpointVnet.outputs.location
    tags: tags
    timeStamp: timeStamp
  }
}

module policy 'policy.bicep' = if (deployDiskAccessPolicy) {
  name: 'ManagedDisks_NetworkAccess_Policy_${timeStamp}'
  params: {
    diskAccessId: deployDiskAccessResource ? diskAccess.outputs.resourceId : ''
    location: locationVirtualMachines
    resourceGroupName: resourceGroupHosts
  }
}

resource keyVault_Ref 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (contains(identitySolution, 'DomainServices') && (empty(domainJoinUserPassword) || empty(domainJoinUserPrincipalName)) || empty(virtualMachineAdminPassword) || empty(virtualMachineAdminUserName)) {
  name: keyVaultNames.VMs
  scope: resourceGroup(resourceGroupManagement)
}

module vmKeyVault 'keyVault.bicep' = if (!empty(virtualMachineAdminPassword) || !empty(virtualMachineAdminUserName) || !empty(domainJoinUserPassword) || !empty(domainJoinUserPrincipalName)) {
  name: 'KeyVault_VMs_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    enabledForTemplateDeployment: true
    enablePurgeProtection: confidentialVMOSDiskEncryption || contains(keyManagementDisks, 'CustomerManaged') ? true : false
    envShortName: envShortName
    keyVaultName: keyVaultNames.VMs
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    location: locationVirtualMachines
    privateEndpoint: privateEndpoint
    privateEndpointLocation: privateEndpoint && !empty(privateEndpointSubnetResourceId) ? privateEndpointVnet.outputs.location : ''
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    skuName: confidentialVMOSDiskEncryption || contains(keyManagementDisks, 'HSM') ? 'premium' : 'standard'
    tagsKeyVault: tags[?'Microsoft.KeyVault/vaults'] ?? {}
    tagsPrivateEndpoints: tags[?'Microsoft.Network/privateEndpoints'] ?? {}
    timeStamp: timeStamp
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
    domainJoinUserPassword: !contains(identitySolution, 'DomainServices')
      ? ''
      : !empty(domainJoinUserPassword) ? domainJoinUserPassword : keyVault_Ref.getSecret('domainJoinUserPassword')
    domainJoinUserPrincipalName: !contains(identitySolution, 'DomainServices')
      ? ''
      : !empty(domainJoinUserPrincipalName)
          ? domainJoinUserPrincipalName
          : keyVault_Ref.getSecret('domainJoinUserPrincipalName')
    domainName: domainName
    encryptionAtHost: encryptionAtHost
    location: locationVirtualMachines
    networkInterfaceName: virtualMachineNICName
    subnetResourceId: virtualMachineSubnetResourceId
    tagsNetworkInterfaces: tags[?'Microsoft.Network/networkInterfaces'] ?? {}
    tagsVirtualMachines: tags[?'Microsoft.Compute/virtualMachines'] ?? {}
    userAssignedIdentitiesResourceIds: empty(artifactsUserAssignedIdentityResourceId)
      ? {
          '${artifactsUserAssignedIdentity.outputs.resourceId}': {}
          '${deploymentUserAssignedIdentity.outputs.resourceId}': {}
        }
      : {
          '${existingArtifactsUserAssignedIdentity.id}': {}
          '${deploymentUserAssignedIdentity.outputs.resourceId}': {}
        }
    virtualMachineName: virtualMachineName
    virtualMachineAdminPassword: !empty(virtualMachineAdminPassword)
      ? virtualMachineAdminPassword
      : keyVault_Ref.getSecret('virtualMachineAdminPassword')
    virtualMachineAdminUserName: !empty(virtualMachineAdminUserName)
      ? virtualMachineAdminUserName
      : keyVault_Ref.getSecret('virtualMachineAdminUserName')
    vmSize: managementVmSize
  }
}

module customerManagedKeys 'customerManagedKeys.bicep' = if (keyManagementDisks != 'PlatformManaged' || confidentialVMOSDiskEncryption || keyManagementFSLogixStorage != 'MicrosoftManaged') {
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
    keyManagementFSLogixStorage: keyManagementFSLogixStorage
    keyManagementDisks: keyManagementDisks
    vmKeyVaultName: last(split(vmKeyVault.outputs.keyVaultResourceId, '/'))
    storageKeyVaultNameConv: keyVaultNames.StorageAccounts
    storageIndex: fslogixStorageIndex
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    envShortName: envShortName
    location: locationVirtualMachines
    managementVirtualMachineName: virtualMachine.outputs.Name
    privateEndpoint: privateEndpoint
    privateEndpointLocation: privateEndpoint && !empty(privateEndpointSubnetResourceId) ? privateEndpointVnet.outputs.location : ''
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    tags: tags
    timeStamp: timeStamp
    userAssignedIdentityNameConv: userAssignedIdentityNameConv
    storageCount: storageCount
  }
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
    privateEndpointLocation: privateEndpoint && !empty(privateEndpointSubnetResourceId) ? privateEndpointVnet.outputs.location : ''
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    timeStamp: timeStamp
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
output artifactsUserAssignedIdentityResourceId string = empty(artifactsUserAssignedIdentityResourceId)
  ? artifactsUserAssignedIdentity.outputs.resourceId
  : existingArtifactsUserAssignedIdentity.id
output diskAccessResourceId string = deployDiskAccessResource ? diskAccess.outputs.resourceId : ''
output diskEncryptionSetResourceId string = keyManagementDisks != 'PlatformManaged'
  ? customerManagedKeys.outputs.diskEncryptionSetResourceId
  : ''
output encryptionUserAssignedIdentityResourceId string = keyManagementDisks != 'PlatformManaged'
  ? customerManagedKeys.outputs.encryptionUserAssignedIdentityResourceId
  : ''
output storageEncryptionKeyKeyVaultUris array = keyManagementFSLogixStorage != 'MicrosoftManaged'
  ? customerManagedKeys.outputs.storageEncryptionKeyKeyVaultUris
  : []
output deploymentUserAssignedIdentityClientId string = deploymentUserAssignedIdentity.outputs.clientId
output deploymentUserAssignedIdentityResourceId string = deploymentUserAssignedIdentity.outputs.resourceId
output storageAccountEncryptionKeyName string = keyManagementFSLogixStorage != 'MicrosoftManaged'
  ? customerManagedKeys.outputs.storageKeyName
  : ''
output virtualMachineName string = virtualMachine.outputs.Name
