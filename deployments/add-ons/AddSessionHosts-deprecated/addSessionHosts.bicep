targetScope = 'subscription'

param artifactsContainerUri string
param artifactsUserAssignedIdentityResourceId string
param availability string
param availabilitySetNamePrefix string
param availabilitySetsIndex int
param availabilityZones array
param avdInsightsDataCollectionRulesResourceId string
param confidentialVMOSDiskEncryption bool
param customImageResourceId string
param dataCollectionEndpointResourceId string
param dedicatedHostGroupResourceId string
param dedicatedHostGroupZones array
param dedicatedHostResourceId string
param deploymentVirtualMachineName string
param diskEncryptionSetResourceId string
param diskAccessResourceId string
param diskNamePrefix string
param diskSizeGB int
param diskSku string
param domainName string
param drainMode bool
param drainModeUserAssignedIdentityClientId string
param enableAcceleratedNetworking bool
param enableMonitoring bool
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
param keyVaultResourceId string
param location string
param networkInterfaceNamePrefix string
param ouPath string
param pooledHostPool bool
param recoveryServices bool
param recoveryServicesVaultResourceId string
param resourceGroupDeployment string
param resourceGroupHosts string
param secureBootEnabled bool
param securityDataCollectionRulesResourceId string
param securityType string
param sessionHostCount int
param sessionHostCustomizations array
param sessionHostRegistrationDSCUrl string
param sessionHostIndex int
param subnetResourceId string
param tags object
param timeStamp string
param useAgentDownloadEndpoint bool
param virtualMachineNamePrefix string
param virtualMachineSize string
param vTpmEnabled bool
param vmInsightsDataCollectionRulesResourceId string

var backupPolicyName = 'AvdPolicyVm'
var confidentialVMOSDiskEncryptionType = confidentialVMOSDiskEncryption ? 'DiskWithVMGuestState' : 'VMGuestStateOnly'

var maxResourcesPerTemplateDeployment = 40 // This is the max number of session hosts that can be deployed from the sessionHosts.bicep file in each batch / for loop. Math: (800 - <Number of Static Resources>) / <Number of Looped Resources> 
var divisionValue = sessionHostCount / maxResourcesPerTemplateDeployment // This determines if any full batches are required.
var divisionRemainderValue = sessionHostCount % maxResourcesPerTemplateDeployment // This determines if any partial batches are required.
var sessionHostBatchCount = divisionRemainderValue > 0 ? divisionValue + 1 : divisionValue // This determines the total number of batches needed, whether full and / or partial.

//  BATCH AVAILABILITY SETS
// The following variables are used to determine the number of availability sets.
var maxAvSetMembers = 200 // This is the max number of session hosts that can be deployed in an availability set.
var beginAvSetRange = sessionHostIndex / maxAvSetMembers // This determines the availability set to start with.
var endAvSetRange = (sessionHostCount + sessionHostIndex) / maxAvSetMembers // This determines the availability set to end with.
var availabilitySetsCount = length(range(beginAvSetRange, (endAvSetRange - beginAvSetRange) + 1))

// create new arrays that always contain the profile-containers volume as the first element.
var localNetAppProfileContainerVolumeResourceIds = !empty(fslogixLocalNetAppVolumeResourceIds) ? filter(fslogixLocalNetAppVolumeResourceIds, id => contains(id, fslogixFileShareNames[0])) : []
var localNetAppOfficeContainerVolumeResourceIds = !empty(fslogixLocalNetAppVolumeResourceIds) && length(fslogixFileShareNames) > 1 ? filter(fslogixLocalNetAppVolumeResourceIds, id => contains(id, fslogixFileShareNames[1])) : []
var sortedLocalNetAppResourceIds = union(localNetAppProfileContainerVolumeResourceIds, localNetAppOfficeContainerVolumeResourceIds)
var remoteNetAppProfileContainerVolumeResourceIds = !empty(fslogixRemoteNetAppVolumeResourceIds) ? filter(fslogixRemoteNetAppVolumeResourceIds, id => contains(id, fslogixFileShareNames[0])) : []
var remoteNetAppOfficeContainerVolumeResourceIds = !empty(fslogixRemoteNetAppVolumeResourceIds) && length(fslogixFileShareNames) > 1 ? filter(fslogixRemoteNetAppVolumeResourceIds, id => !contains(id, fslogixFileShareNames[0])) : []
var sortedRemoteNetAppResourceIds = union(remoteNetAppProfileContainerVolumeResourceIds, remoteNetAppOfficeContainerVolumeResourceIds)

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: last(split(keyVaultResourceId, '/'))
  scope: resourceGroup(split(keyVaultResourceId, '/')[2], split(keyVaultResourceId, '/')[4])
}

module artifactsUserAssignedIdentity 'modules/sessionHosts/modules/getUserAssignedIdentity.bicep' = if(!empty(artifactsUserAssignedIdentityResourceId)) {
  name: 'ArtifactsUserAssignedIdentity_${timeStamp}'
  params: {
    userAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
  }
}

module availabilitySets '../sharedModules/resources/compute/availability-set/main.bicep' = [for i in range(0, availabilitySetsCount): if (pooledHostPool && availability == 'AvailabilitySets') {
  name: '${availabilitySetNamePrefix}${padLeft((i + availabilitySetsIndex), 2, '0')}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    name: '${availabilitySetNamePrefix}${padLeft((i + availabilitySetsIndex), 2, '0')}'
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
    proximityPlacementGroupResourceId: ''
    location: location
    skuName: 'Aligned'
    tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.Compute/availabilitySets'] ?? {})
  }
}]

module localNetAppVolumes 'modules/sessionHosts/modules/getNetAppVolumeSmbServerFqdn.bicep' = [for i in range(0, length(sortedLocalNetAppResourceIds)): if(!empty(sortedLocalNetAppResourceIds)) {
  name: 'localNetAppVolumes-${i}-${timeStamp}'
  params: {
    netAppVolumeResourceId: sortedLocalNetAppResourceIds[i]
  }
}]

module remoteNetAppVolumes 'modules/sessionHosts/modules/getNetAppVolumeSmbServerFqdn.bicep' = [for i in range(0, length(sortedRemoteNetAppResourceIds)) : if(!empty(sortedRemoteNetAppResourceIds)) {
  name: 'remoteNetAppVolumes-${i}-${timeStamp}'
  params: {
    netAppVolumeResourceId: sortedRemoteNetAppResourceIds[i]
  }
}]

@batchSize(5)
module virtualMachines 'modules/sessionHosts/modules/virtualMachines.bicep' = [for i in range(1, sessionHostBatchCount): {
  name: 'VirtualMachines_Batch_${i-1}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    artifactsContainerUri: artifactsContainerUri
    artifactsUserAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
    artifactsUserAssignedIdentityClientId: empty(artifactsUserAssignedIdentityResourceId) ? '' : artifactsUserAssignedIdentity.outputs.clientId
    availability: availability
    availabilityZones: availabilityZones
    availabilitySetNamePrefix: availabilitySetNamePrefix
    batchCount: i
    confidentialVMOSDiskEncryptionType: confidentialVMOSDiskEncryptionType
    customImageResourceId: customImageResourceId
    dataCollectionEndpointResourceId: dataCollectionEndpointResourceId
    dedicatedHostGroupResourceId: dedicatedHostGroupResourceId
    dedicatedHostGroupZones: dedicatedHostGroupZones
    dedicatedHostResourceId: dedicatedHostResourceId
    diskAccessId: diskAccessResourceId
    diskEncryptionSetResourceId:diskEncryptionSetResourceId
    diskNamePrefix: diskNamePrefix
    diskSizeGB: diskSizeGB
    diskSku: diskSku
    domainJoinUserPassword: contains(identitySolution, 'DS') ? keyVault.getSecret('DomainJoinUserPassword') : ''
    domainJoinUserPrincipalName: contains(identitySolution, 'DS') ? keyVault.getSecret('DomainJoinUserPrincipalName') : ''
    domainName: domainName
    drainMode: drainMode
    drainModeUserAssignedIdentityClientId: drainModeUserAssignedIdentityClientId
    enableAcceleratedNetworking: enableAcceleratedNetworking
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
    identitySolution: identitySolution
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    integrityMonitoring: integrityMonitoring
    location: location
    deploymentVirtualMachineName: deploymentVirtualMachineName
    enableMonitoring: enableMonitoring
    networkInterfaceNamePrefix: networkInterfaceNamePrefix
    ouPath: ouPath
    sessionHostCustomizations: sessionHostCustomizations
    avdInsightsDataCollectionRulesResourceId: avdInsightsDataCollectionRulesResourceId
    vmInsightsDataCollectionRulesResourceId: vmInsightsDataCollectionRulesResourceId 
    resourceGroupDeployment: resourceGroupDeployment
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    secureBootEnabled: secureBootEnabled
    securityType: securityType
    sessionHostCount: i == sessionHostBatchCount && divisionRemainderValue > 0 ? divisionRemainderValue : maxResourcesPerTemplateDeployment
    sessionHostIndex: i == 1 ? sessionHostIndex : ((i - 1) * maxResourcesPerTemplateDeployment) + sessionHostIndex
    sessionHostRegistrationDSCUrl: sessionHostRegistrationDSCUrl
    storageSuffix: environment().suffixes.storage
    subnetResourceId: subnetResourceId
    tags: tags
    timeStamp: timeStamp
    useAgentDownloadEndpoint: useAgentDownloadEndpoint
    virtualMachineAdminPassword: keyVault.getSecret('VirtualMachineAdminPassword')
    virtualMachineAdminUserName: keyVault.getSecret('VirtualMachineAdminUserName')
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
    vTpmEnabled: vTpmEnabled
  }
  dependsOn: [
    availabilitySets
  ]
}]

module protectedItems_Vm 'modules/sessionHosts/modules/protectedItems.bicep' = [for i in range(1, sessionHostBatchCount): if (recoveryServices) {
  name: 'BackupProtectedItems_VirtualMachines_${i-1}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    location: location
    PolicyId: recoveryServices ? '${recoveryServicesVaultResourceId}/backupPolicies/${backupPolicyName}' : ''
    recoveryServicesVaultName: recoveryServices ? last(split(recoveryServicesVaultResourceId, '/')) : ''
    sessionHostCount: i == sessionHostBatchCount && divisionRemainderValue > 0 ? divisionRemainderValue : maxResourcesPerTemplateDeployment
    sessionHostIndex: i == 1 ? sessionHostIndex : ((i - 1) * maxResourcesPerTemplateDeployment) + sessionHostIndex
    tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.recoveryServices/vaults'] ?? {})
    virtualMachineNamePrefix: virtualMachineNamePrefix
    VirtualMachineResourceGroupName: resourceGroupHosts
  }
  dependsOn: [
    virtualMachines[i-1]
  ]
}]

module getFlattenedVmNamesArray 'modules/sessionHosts/modules/flattenVirtualMachineNames.bicep' = {
  name: 'FlattenVirtualMachineNames_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    virtualMachineNamesPerBatch: [for i in range(1, sessionHostBatchCount):virtualMachines[i-1].outputs.virtualMachineNames]
  }
}

output virtualMachineNames array = getFlattenedVmNamesArray.outputs.virtualMachineNames
