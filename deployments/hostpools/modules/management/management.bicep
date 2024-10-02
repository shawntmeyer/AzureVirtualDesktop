targetScope = 'subscription'

param identitySolution string
param azureBlobsPrivateDnsZoneResourceId string
param avdObjectId string
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
param encryptionAtHost bool
param envShortName string
param fslogix bool
param fslogixStorageIndex int
param keyManagementFSLogixStorage string
param fslogixStorageSolution string
param hostPoolType string
param keyVaultNames object
param keyVaultPrivateDnsZoneResourceId string
param privateEndpointSubnetResourceId string
param locationVirtualMachines string
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

var deploymentUserAssignedIdentityName = replace(userAssignedIdentityNameConv, 'UAIPURPOSE', 'avd-deployment')

var confidentialVMOSDiskEncryption = confidentialVMOSDiskEncryptionType == 'DiskWithVMGuestState' ? true : false
var diskEncryptionSetEncryptionType = confidentialVMOSDiskEncryption
  ? 'ConfidentialVmEncryptedWithCustomerKey'
  : (!contains(keyManagementDisks, 'Platform')
      ? 'EncryptionAtRestWithCustomerKey'
      : 'EncryptionAtRestWithPlatformAndCustomerKeys')

var roleAssignmentsControlPlane = [
  {
    roleDefinitionId: roleDefinitions.DesktopVirtualizationApplicationGroupContributor // (Purpose: updates the friendly name for the desktop)
    depName: 'DVAppGroupCont-ControlPlane'
    resourceGroup: resourceGroupControlPlane
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.DesktopVirtualizationSessionHostOperator // (Purpose: sets drain mode on the AVD session hosts)
    depName: 'DVSessionHostOp-ControlPlane'
    resourceGroup: resourceGroupControlPlane
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.DesktopVirtualizationWorkspaceContributor // (Purpose: update the app group references on an existing feed workspace)
    depName: 'DVWorkspaceCont-ControlPlane'
    resourceGroup: resourceGroupControlPlane
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.RoleBasedAccessControlAdministrator // (Purpose: remove the control plane role assignments for the deployment identity. This role Assignment must remain last in the list.)
    depName: 'RBACAdmin-ControlPlane'
    resourceGroup: resourceGroupControlPlane
    subscription: subscription().subscriptionId
  }
]

var roleAssignmentsHosts = [
  {
    roleDefinitionId: roleDefinitions.VirtualMachineContributor // (Purpose: remove the run commands from the host VMs)
    depName: 'VMCont-Hosts'
    resourceGroup: resourceGroupHosts
    subscription: subscription().subscriptionId
  }
  {
    roleDefinitionId: roleDefinitions.RoleBasedAccessControlAdministrator // (Purpose: remove the hosts rsource group role assignment for the deployment identity. This role Assignment must remain last in the list.)
    depName: 'RBACAdmin-Hosts'
    resourceGroup: resourceGroupHosts
    subscription: subscription().subscriptionId
  }
]

var roleAssignmentsManagement = confidentialVMOSDiskEncryption && contains(keyManagementDisks, 'CustomerManaged')
  ? [
      {
        roleDefinitionId: roleDefinitions.VirtualMachineContributor // (Purpose: remove the management virtual machine)
        depName: 'VMCont-Management'
        resourceGroup: resourceGroupManagement
        subscription: subscription().subscriptionId
      }
      {
        roleDefinitionId: roleDefinitions.KeyVaultCryptoOfficer // (Purpose: Retrieve the customer managed keys from the key vault for idempotent deployment)
        depName: 'KVCryptoOff-Management'
        resourceGroup: resourceGroupManagement
        subscription: subscription().subscriptionId
      }
    ]
  : [
      {
        roleDefinitionId: roleDefinitions.VirtualMachineContributor // (Purpose: remove the management virtual machine)
        depName: 'VMCont-Management'
        resourceGroup: resourceGroupManagement
        subscription: subscription().subscriptionId
      }
    ]

var roleAssignmentStorage = fslogix && contains(identitySolution, 'DomainServices')
  ? [
      {
        roleDefinitionId: roleDefinitions.StorageAccountContributor // (Purpose: domain join storage account & set NTFS permissions on the file share)
        depName: 'StorageAcctCont-Storage'
        resourceGroup: resourceGroupStorage
        subscription: subscription().subscriptionId
      }
      {
        roleDefinitionId: roleDefinitions.RoleBasedAccessControlAdministrator // (Purpose: remove the control plane role assignments for the deployment identity. This role assignment must remain last in the list.)
        depName: 'RBACAdmin-Storage'
        resourceGroup: resourceGroupStorage
        subscription: subscription().subscriptionId
      }
    ]
  : []
var roleAssignments = union(roleAssignmentsControlPlane, roleAssignmentsHosts, roleAssignmentsManagement, roleAssignmentStorage)

// Role Assignment required for Start VM On Connect
resource roleAssignment_PowerOnContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(avdObjectId, roleDefinitions.DesktopVirtualizationPowerOnContributor, subscription().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.DesktopVirtualizationPowerOnContributor)
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

module deploymentUserAssignedIdentity 'modules/userAssignedIdentity.bicep' = {
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
    name: 'RA-${roleAssignments[i].depName}-${timeStamp}'
    params: {
      principalId: deploymentUserAssignedIdentity.outputs.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: roleAssignments[i].roleDefinitionId
    }
  }
]

module privateEndpointVnet '../common/vnetLocation.bicep' = if (privateEndpoint && !empty(privateEndpointSubnetResourceId)) {
  name: 'PrivateEndpointVnet_${timeStamp}'
  params: {
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
  }
}

module diskAccess 'modules/diskAccess.bicep' = if (deployDiskAccessResource) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'DiskAccess_${timeStamp}'
  params: {
    diskAccessName: diskAccessName
    location: locationVirtualMachines
    privateDNSZoneResourceId: azureBlobsPrivateDnsZoneResourceId
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    privateEndpointLocation: privateEndpoint && !empty(privateEndpointSubnetResourceId)
      ? privateEndpointVnet.outputs.location
      : ''
    tags: tags
    timeStamp: timeStamp
  }
}

module policy 'modules/policy.bicep' = if (deployDiskAccessPolicy) {
  name: 'ManagedDisks_NetworkAccess_Policy_${timeStamp}'
  params: {
    diskAccessId: deployDiskAccessResource ? diskAccess.outputs.resourceId : ''
    location: locationVirtualMachines
    resourceGroupName: resourceGroupHosts
  }
}

module vmKeyVault 'modules/keyVault.bicep' = if (confidentialVMOSDiskEncryption || contains(
  keyManagementDisks,
  'CustomerManaged'
)) {
  name: 'KeyVault_VMs_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    enablePurgeProtection: confidentialVMOSDiskEncryption || contains(keyManagementDisks, 'CustomerManaged')
      ? true
      : false
    envShortName: envShortName
    keyVaultName: keyVaultNames.VMs
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    location: locationVirtualMachines
    privateEndpoint: privateEndpoint
    privateEndpointLocation: privateEndpoint && !empty(privateEndpointSubnetResourceId)
      ? privateEndpointVnet.outputs.location
      : ''
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    skuName: confidentialVMOSDiskEncryption || contains(keyManagementDisks, 'HSM') ? 'premium' : 'standard'
    tags: tags
    timeStamp: timeStamp
  }
}

// Management VM
// The management VM is required to validate the deployment and configure FSLogix storage. This deployment does not use customer managed keys for the management machine to allow it to remain idempotent.
module virtualMachine 'modules/virtualMachine.bicep' = {
  name: 'ManagementVirtualMachine_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    identitySolution: identitySolution
    diskName: virtualMachineDiskName
    diskSku: diskSku
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainName: domainName
    encryptionAtHost: encryptionAtHost
    location: locationVirtualMachines
    networkInterfaceName: virtualMachineNICName
    subnetResourceId: virtualMachineSubnetResourceId
    tagsNetworkInterfaces: tags[?'Microsoft.Network/networkInterfaces'] ?? {}
    tagsVirtualMachines: tags[?'Microsoft.Compute/virtualMachines'] ?? {}
    userAssignedIdentitiesResourceIds: {
      '${deploymentUserAssignedIdentity.outputs.resourceId}': {}
    }
    virtualMachineName: virtualMachineName
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineAdminUserName: virtualMachineAdminUserName
    vmSize: managementVmSize
  }
}

module customerManagedKeys 'modules/customerManagedKeys.bicep' = if (keyManagementDisks != 'PlatformManaged' || confidentialVMOSDiskEncryption || keyManagementFSLogixStorage != 'MicrosoftManaged') {
  name: 'CustomerManagedKeys_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    confidentialVMOrchestratorObjectId: confidentialVMOrchestratorObjectId
    confidentialVMOSDiskEncryption: confidentialVMOSDiskEncryption
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentity.outputs.clientId
    diskEncryptionSetEncryptionType: diskEncryptionSetEncryptionType
    diskEncryptionSetNames: diskEncryptionSetNames
    keyManagementFSLogixStorage: keyManagementFSLogixStorage
    keyManagementDisks: keyManagementDisks
    vmKeyVaultName: confidentialVMOSDiskEncryption || contains(keyManagementDisks, 'CustomerManaged')
      ? last(split(vmKeyVault.outputs.keyVaultResourceId, '/'))
      : ''
    storageKeyVaultNameConv: keyVaultNames.StorageAccounts
    storageIndex: fslogixStorageIndex
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    envShortName: envShortName
    location: locationVirtualMachines
    managementVirtualMachineName: virtualMachine.outputs.Name
    privateEndpoint: privateEndpoint
    privateEndpointLocation: privateEndpoint && !empty(privateEndpointSubnetResourceId)
      ? privateEndpointVnet.outputs.location
      : ''
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    tags: tags
    timeStamp: timeStamp
    userAssignedIdentityNameConv: userAssignedIdentityNameConv
    storageCount: storageCount
  }
}

module recoveryServicesVault 'modules/recoveryServicesVault.bicep' = if (recoveryServices) {
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

output deploymentUserAssignedIdentityClientId string = deploymentUserAssignedIdentity.outputs.clientId
output deploymentUserAssignedIdentityResourceId string = deploymentUserAssignedIdentity.outputs.resourceId
output deploymentUserAssignedIdentityRoleAssignmentIds array = [for i in range(0, length(roleAssignments)): roleAssignments_deployment[i].outputs.resourceId]
output diskAccessResourceId string = deployDiskAccessResource ? diskAccess.outputs.resourceId : ''
output diskEncryptionSetResourceId string = keyManagementDisks != 'PlatformManaged'
  ? customerManagedKeys.outputs.diskEncryptionSetResourceId
  : ''
output encryptionUserAssignedIdentityResourceId string = keyManagementDisks != 'PlatformManaged'
  ? customerManagedKeys.outputs.encryptionUserAssignedIdentityResourceId
  : ''

output storageAccountEncryptionKeyName string = keyManagementFSLogixStorage != 'MicrosoftManaged'
  ? customerManagedKeys.outputs.storageKeyName
  : ''
output storageEncryptionKeyKeyVaultUris array = keyManagementFSLogixStorage != 'MicrosoftManaged'
  ? customerManagedKeys.outputs.storageEncryptionKeyKeyVaultUris
  : []
output virtualMachineName string = virtualMachine.outputs.Name
