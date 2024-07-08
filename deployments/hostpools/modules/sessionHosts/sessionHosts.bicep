targetScope = 'subscription'

param acceleratedNetworking string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param artifactsUserAssignedIdentityResourceId string
param availability string
param availabilitySetNamePrefix string
param availabilitySetsCount int
param availabilitySetsIndex int
param availabilityZones array
param confidentialVMOSDiskEncryptionType string
param cseMasterScript string
param cseScriptAddDynParameters string
param cseUris array
param customImageResourceId string
param dataCollectionEndpointResourceId string
param dedicatedHostGroupResourceId string
param dedicatedHostGroupZones array
param dedicatedHostResourceId string
param avdInsightsDataCollectionRulesResourceId string
param vmInsightsDataCollectionRulesResourceId string
param diskEncryptionSetResourceId string
param diskNamePrefix string
param diskSku string
param divisionRemainderValue int
param domainName string
param drainMode bool
param drainModeUserAssignedIdentityClientId string
param encryptionAtHost bool
param fslogixConfigureSessionHosts bool
param fslogixExistingStorageAccountResourceIds array
param fslogixContainerType string
param fslogixDeployedStorageAccountResourceIds array
param hostPoolName string
param identitySolution string
param imageOffer string
param imagePublisher string
param imageSku string
param keyVaultName string
param location string
param managementVirtualMachineName string
param maxResourcesPerTemplateDeployment int
param enableMonitoring bool
param networkInterfaceNamePrefix string
param ouPath string
param pooledHostPool bool
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupControlPlane string
param resourceGroupHosts string
param resourceGroupManagement string
param roleDefinitions object
param securityDataCollectionRulesResourceId string
param securityPrincipalObjectIds array
param securityLogAnalyticsWorkspaceResourceId string
param securityType string
param sessionHostBatchCount int
param sessionHostIndex int
param storageSuffix string
param subnetResourceId string
param tags object
param timeStamp string
param virtualMachineNamePrefix string
param virtualMachineSize string


var tagsAvailabilitySets = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Compute/availabilitySets') ? tags['Microsoft.Compute/availabilitySets'] : {})
var tagsNetworkInterfaces = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Network/networkInterfaces') ? tags['Microsoft.Network/networkInterfaces'] : {})
var tagsRecoveryServicesVault = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.recoveryServices/vaults') ? tags['Microsoft.recoveryServices/vaults'] : {})
var tagsVirtualMachines = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {})

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(resourceGroupManagement)
}

module fslogixStorageAccountResourceIds 'fslogix/resolveStorageAccountResourceIds.bicep' = if(fslogixConfigureSessionHosts && (!empty(fslogixDeployedStorageAccountResourceIds) || !empty(fslogixExistingStorageAccountResourceIds))) {
  name: 'Fslogix_Storage_Logic_${timeStamp}'
  params: {
    fslogixContainerType: fslogixContainerType
    deployedStorageAccountResourceIds: fslogixDeployedStorageAccountResourceIds
    existingStorageAccountResourceIds: fslogixExistingStorageAccountResourceIds
    location: location
  }
}

module availabilitySets 'availabilitySets.bicep' = if (pooledHostPool && availability == 'AvailabilitySets') {
  name: 'AvailabilitySets_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    availabilitySetNamePrefix: availabilitySetNamePrefix
    availabilitySetsCount: availabilitySetsCount
    availabilitySetsIndex: availabilitySetsIndex
    location: location
    tagsAvailabilitySets: tagsAvailabilitySets
  }
}

// Role Assignment for Virtual Machine Login User
// This module deploys the role assignments to login to Azure AD joined session hosts
module roleAssignments '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = [for i in range(0, length(securityPrincipalObjectIds)): if (!contains(identitySolution, 'DomainServices')) {
  name: 'RoleAssignments_${i}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    principalId: securityPrincipalObjectIds[i]
    principalType: 'Group'
    roleDefinitionId: roleDefinitions.VirtualMachineUserLogin
  }
}]

@batchSize(1)
module virtualMachines 'virtualMachines.bicep' = [for i in range(1, sessionHostBatchCount): {
  name: 'VirtualMachines_${i - 1}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    acceleratedNetworking: acceleratedNetworking
    identitySolution: identitySolution
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    availability: availability
    availabilityZones: availabilityZones
    availabilitySetNamePrefix: availabilitySetNamePrefix
    batchCount: i
    confidentialVMOSDiskEncryptionType: confidentialVMOSDiskEncryptionType
    cseMasterScript: cseMasterScript
    cseScriptAddDynParameters: cseScriptAddDynParameters
    cseUris: cseUris
    customImageResourceId: customImageResourceId
    dataCollectionEndpointResourceId: dataCollectionEndpointResourceId
    dedicatedHostGroupResourceId: dedicatedHostGroupResourceId
    dedicatedHostGroupZones: dedicatedHostGroupZones
    dedicatedHostResourceId: dedicatedHostResourceId
    diskEncryptionSetResourceId: diskEncryptionSetResourceId
    diskNamePrefix: diskNamePrefix
    diskSku: diskSku
    domainJoinUserPassword: contains(identitySolution, 'DomainServices') ? keyVault.getSecret('domainJoinUserPassword') : ''
    domainJoinUserPrincipalName: contains(identitySolution, 'DomainServices') ? keyVault.getSecret('domainJoinUserPrincipalName') : ''
    domainName: domainName
    drainMode: drainMode
    drainModeUserAssignedIdentityClientId: drainModeUserAssignedIdentityClientId
    encryptionAtHost: encryptionAtHost
    fslogixConfigureSessionHosts: fslogixConfigureSessionHosts
    fslogixContainerType: fslogixContainerType
    fslogixStorageAccountResourceIds: fslogixConfigureSessionHosts && (!empty(fslogixDeployedStorageAccountResourceIds) || !empty(fslogixExistingStorageAccountResourceIds)) ? fslogixStorageAccountResourceIds.outputs.storageAccountResourceIds : []
    hostPoolName: hostPoolName
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    enableMonitoring: enableMonitoring
    networkInterfaceNamePrefix: networkInterfaceNamePrefix
    ouPath: ouPath
    avdInsightsDataCollectionRulesResourceId: avdInsightsDataCollectionRulesResourceId
    vmInsightsDataCollectionRulesResourceId: vmInsightsDataCollectionRulesResourceId 
    resourceGroupControlPlane: resourceGroupControlPlane
    resourceGroupManagement: resourceGroupManagement
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    securityLogAnalyticsWorkspaceResourceId: securityLogAnalyticsWorkspaceResourceId
    securityType: securityType
    sessionHostCount: i == sessionHostBatchCount && divisionRemainderValue > 0 ? divisionRemainderValue : maxResourcesPerTemplateDeployment
    sessionHostIndex: i == 1 ? sessionHostIndex : ((i - 1) * maxResourcesPerTemplateDeployment) + sessionHostIndex
    storageSuffix: storageSuffix
    subnetResourceId: subnetResourceId
    tagsNetworkInterfaces: tagsNetworkInterfaces
    tagsVirtualMachines: tagsVirtualMachines
    timeStamp: timeStamp
    virtualMachineAdminPassword: keyVault.getSecret('virtualMachineAdminPassword')
    virtualMachineAdminUserName: keyVault.getSecret('virtualMachineAdminUserName')
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
  }
  dependsOn: [
    availabilitySets
  ]
}]

module recServices 'recoveryServices.bicep' = if (recoveryServices) {
  name: 'RecoveryServices_VirtualMachines_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    divisionRemainderValue: divisionRemainderValue
    pooledHostPool: pooledHostPool
    location: location
    maxResourcesPerTemplateDeployment: maxResourcesPerTemplateDeployment
    recoveryServicesVaultName: recoveryServicesVaultName
    resourceGroupHosts: resourceGroupHosts
    resourceGroupManagement: resourceGroupManagement
    sessionHostBatchCount: sessionHostBatchCount
    sessionHostIndex: sessionHostIndex
    tagsRecoveryServicesVault: tagsRecoveryServicesVault
    timeStamp: timeStamp
    virtualMachineNamePrefix: virtualMachineNamePrefix
  }
  dependsOn: [
    virtualMachines
  ]
}
