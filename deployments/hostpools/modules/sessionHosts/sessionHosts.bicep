targetScope = 'subscription'

param artifactsUserAssignedIdentityResourceId string
param availability string
param availabilitySetNamePrefix string
param availabilitySetsCount int
param availabilitySetsIndex int
param availabilityZones array
param avdAgentsModuleUrl string
param avdInsightsDataCollectionRulesResourceId string
param confidentialVMOSDiskEncryptionType string
param cseMasterScript string
param cseScriptAddDynParameters string
param cseUris array
param customImageResourceId string
param dataCollectionEndpointResourceId string
param dedicatedHostGroupResourceId string
param dedicatedHostGroupZones array
param dedicatedHostResourceId string
param deploymentUserAssignedIdentityClientId string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param enableAcceleratedNetworking bool
param diskAccessId string
param diskEncryptionSetResourceId string
param diskNamePrefix string
param diskSizeGB int
param diskSku string
param divisionRemainderValue int
param domainName string
param drainMode bool
param drainModeUserAssignedIdentityClientId string
param encryptionAtHost bool
param fslogixFileShareNames array
param fslogixConfigureSessionHosts bool
param fslogixContainerType string
param fslogixLocalNetAppVolumeResourceIds array
param fslogixLocalStorageAccountResourceIds array
param fslogixOSSGroups array
param fslogixRemoteNetAppVolumeResourceIds array
param fslogixRemoteStorageAccountResourceIds array
param fslogixStorageService string
param hibernationEnabled bool
param hostPoolResourceId string
param identitySolution string
param imageOffer string
param imagePublisher string
param imageSku string
param integrityMonitoring bool
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
param appGroupSecurityGroups array
param securityType string
param secureBootEnabled bool
param vTpmEnabled bool
param sessionHostBatchCount int
param sessionHostIndex int
param storageSuffix string
param subnetResourceId string
param tags object
param timeStamp string
param virtualMachineNamePrefix string
param virtualMachineSize string
@secure()
param virtualMachineAdminPassword string
@secure()
param virtualMachineAdminUserName string
param vmInsightsDataCollectionRulesResourceId string

var hostPoolName = last(split(hostPoolResourceId, '/'))

// create new arrays that always contain the profile-containers volume as the first element.
var localNetAppProfileContainerVolumeResourceIds = !empty(fslogixLocalNetAppVolumeResourceIds) ? filter(fslogixLocalNetAppVolumeResourceIds, id => contains(id, fslogixFileShareNames[0])) : []
var localNetAppOfficeContainerVolumeResourceIds = !empty(fslogixLocalNetAppVolumeResourceIds) && length(fslogixFileShareNames) > 1 ? filter(fslogixLocalNetAppVolumeResourceIds, id => contains(id, fslogixFileShareNames[1])) : []
var sortedLocalNetAppResourceIds = union(localNetAppProfileContainerVolumeResourceIds, localNetAppOfficeContainerVolumeResourceIds)
var remoteNetAppProfileContainerVolumeResourceIds = !empty(fslogixRemoteNetAppVolumeResourceIds) ? filter(fslogixRemoteNetAppVolumeResourceIds, id => contains(id, fslogixFileShareNames[0])) : []
var remoteNetAppOfficeContainerVolumeResourceIds = !empty(fslogixRemoteNetAppVolumeResourceIds) && length(fslogixFileShareNames) > 1 ? filter(fslogixRemoteNetAppVolumeResourceIds, id => !contains(id, fslogixFileShareNames[0])) : []
var sortedRemoteNetAppResourceIds = union(remoteNetAppProfileContainerVolumeResourceIds, remoteNetAppOfficeContainerVolumeResourceIds)

var tagsAvailabilitySets = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, tags[?'Microsoft.Compute/availabilitySets'] ?? {})
var tagsNetworkInterfaces = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, tags[?'Microsoft.Network/networkInterfaces'] ?? {})
var tagsRecoveryServicesVault = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, tags[?'Microsoft.recoveryServices/vaults'] ?? {})
var tagsVirtualMachines = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, tags[?'Microsoft.Compute/virtualMachines'] ?? {})

module artifactsUserAssignedIdentity 'modules/getUserAssignedIdentity.bicep' = if(!empty(artifactsUserAssignedIdentityResourceId)) {
  name: 'ArtifactsUserAssignedIdentity_${timeStamp}'
  params: {
    userAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
  }
}

module availabilitySets 'modules/availabilitySets.bicep' = if (pooledHostPool && availability == 'AvailabilitySets') {
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
module roleAssignments '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = [for i in range(0, length(appGroupSecurityGroups)): if (!contains(identitySolution, 'DomainServices')) {
  name: 'RoleAssignments_${i}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    principalId: appGroupSecurityGroups[i]
    principalType: 'Group'
    roleDefinitionId: roleDefinitions.VirtualMachineUserLogin
  }
}]

module localNetAppVolumes 'modules/getNetAppVolumeSmbServerFqdn.bicep' = [for i in range(0, length(sortedLocalNetAppResourceIds)): if(!empty(sortedLocalNetAppResourceIds)) {
  name: 'localNetAppVolumes-${i}-${timeStamp}'
  params: {
    netAppVolumeResourceId: sortedLocalNetAppResourceIds[i]
  }
}]

module remoteNetAppVolumes 'modules/getNetAppVolumeSmbServerFqdn.bicep' = [for i in range(0, length(sortedRemoteNetAppResourceIds)) : if(!empty(sortedRemoteNetAppResourceIds)) {
  name: 'remoteNetAppVolumes-${i}-${timeStamp}'
  params: {
    netAppVolumeResourceId: sortedRemoteNetAppResourceIds[i]
  }
}]

@batchSize(1)
module virtualMachines 'modules/virtualMachines.bicep' = [for i in range(1, sessionHostBatchCount): {
  name: 'VirtualMachines_${i - 1}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    avdAgentsModuleUrl: avdAgentsModuleUrl
    enableAcceleratedNetworking: enableAcceleratedNetworking
    identitySolution: identitySolution
    artifactsUserAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
    artifactsUserAssignedIdentityClientId: empty(artifactsUserAssignedIdentityResourceId) ? '' : artifactsUserAssignedIdentity.outputs.clientId
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
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    diskAccessId: diskAccessId
    diskEncryptionSetResourceId: diskEncryptionSetResourceId
    diskNamePrefix: diskNamePrefix
    diskSizeGB: diskSizeGB
    diskSku: diskSku
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainName: domainName
    drainMode: drainMode
    drainModeUserAssignedIdentityClientId: drainModeUserAssignedIdentityClientId
    encryptionAtHost: encryptionAtHost
    fslogixConfigureSessionHosts: fslogixConfigureSessionHosts
    fslogixContainerType: fslogixContainerType
    fslogixFileShareNames: fslogixFileShareNames
    fslogixOSSGroups: fslogixOSSGroups
    fslogixLocalNetAppServerFqdns: [for i in range(0, length(sortedLocalNetAppResourceIds)) : localNetAppVolumes[i].outputs.smbServerFqdn]
    fslogixLocalStorageAccountResourceIds: fslogixLocalStorageAccountResourceIds
    fslogixRemoteNetAppServerFqdns: [for i in range(0, length(sortedRemoteNetAppResourceIds)) : remoteNetAppVolumes[i].outputs.smbServerFqdn]
    fslogixRemoteStorageAccountResourceIds: fslogixRemoteStorageAccountResourceIds    
    fslogixStorageService: fslogixStorageService
    hibernationEnabled: hibernationEnabled
    hostPoolResourceId: hostPoolResourceId
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    integrityMonitoring: integrityMonitoring
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    enableMonitoring: enableMonitoring
    networkInterfaceNamePrefix: networkInterfaceNamePrefix
    ouPath: ouPath
    avdInsightsDataCollectionRulesResourceId: avdInsightsDataCollectionRulesResourceId
    vmInsightsDataCollectionRulesResourceId: vmInsightsDataCollectionRulesResourceId 
    resourceGroupManagement: resourceGroupManagement
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    securityType: securityType
    secureBootEnabled: secureBootEnabled
    vTpmEnabled: vTpmEnabled
    sessionHostCount: i == sessionHostBatchCount && divisionRemainderValue > 0 ? divisionRemainderValue : maxResourcesPerTemplateDeployment
    sessionHostIndex: i == 1 ? sessionHostIndex : ((i - 1) * maxResourcesPerTemplateDeployment) + sessionHostIndex
    storageSuffix: storageSuffix
    subnetResourceId: subnetResourceId
    tagsNetworkInterfaces: tagsNetworkInterfaces
    tagsVirtualMachines: tagsVirtualMachines
    timeStamp: timeStamp
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineAdminUserName: virtualMachineAdminUserName
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
  }
  dependsOn: [
    availabilitySets
  ]
}]

module getFlattenedVmNamesArray 'modules/flattenVirtualMachineNames.bicep' = {
  name: 'FlattenVirtualMachineNames_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    virtualMachineNamesPerBatch: [for i in range(1, sessionHostBatchCount):virtualMachines[i-1].outputs.virtualMachineNames]
  }
}

module recServices 'modules/recoveryServices.bicep' = if (recoveryServices) {
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

output virtualMachineNames array = getFlattenedVmNamesArray.outputs.virtualMachineNames
