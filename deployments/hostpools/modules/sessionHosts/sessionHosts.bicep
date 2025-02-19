targetScope = 'subscription'

param appGroupSecurityGroups array
param artifactsContainerUri string
param artifactsUserAssignedIdentityResourceId string
param availability string
param availabilitySetNamePrefix string
param availabilitySetsCount int
param availabilitySetsIndex int
param availabilityZones array
param avdInsightsDataCollectionRulesResourceId string
param azureBackupPrivateDnsZoneResourceId string
param azureBlobPrivateDnsZoneResourceId string
param azureKeyVaultPrivateDnsZoneResourceId string
param azureQueuePrivateDnsZoneResourceId string
param confidentialVMOrchestratorObjectId string
param confidentialVMOSDiskEncryption bool
param customImageResourceId string
param dataCollectionEndpointResourceId string
param dedicatedHostGroupResourceId string
param dedicatedHostGroupZones array
param dedicatedHostResourceId string
param deployDiskAccessPolicy bool
param deployDiskAccessResource bool
param deploymentUserAssignedIdentityClientId string
param deploymentVirtualMachineName string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param diskEncryptionSetNames object
param diskAccessName string
param diskNamePrefix string
param diskSizeGB int
param diskSku string
param divisionRemainderValue int
param domainName string
param drainMode bool
param drainModeUserAssignedIdentityClientId string
param enableAcceleratedNetworking bool
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
param keyExpirationInDays int
param keyManagementDisks string
param keyVaultNames object
param keyVaultRetentionInDays int
param location string
param logAnalyticsWorkspaceResourceId string
param maxResourcesPerTemplateDeployment int
param privateEndpoint bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param privateEndpointSubnetResourceId string
param enableMonitoring bool
param networkInterfaceNamePrefix string
param ouPath string
param pooledHostPool bool
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupDeployment string
param resourceGroupHosts string
param roleDefinitions object
param secureBootEnabled bool
param securityDataCollectionRulesResourceId string
param securityType string
param sessionHostBatchCount int
param sessionHostCustomizations array
param sessionHostRegistrationDSCUrl string
param sessionHostIndex int
param storageSuffix string
param subnetResourceId string
param tags object
param timeStamp string
param timeZone string
param useAgentDownloadEndpoint bool
param virtualMachineNamePrefix string
param virtualMachineSize string
@secure()
param virtualMachineAdminPassword string
@secure()
param virtualMachineAdminUserName string
param vTpmEnabled bool
param vmInsightsDataCollectionRulesResourceId string

var backupPolicyName = 'AvdPolicyVm'
var confidentialVMOSDiskEncryptionType = confidentialVMOSDiskEncryption ? 'DiskWithVMGuestState' : 'VMGuestStateOnly'

// create new arrays that always contain the profile-containers volume as the first element.
var localNetAppProfileContainerVolumeResourceIds = !empty(fslogixLocalNetAppVolumeResourceIds) ? filter(fslogixLocalNetAppVolumeResourceIds, id => contains(id, fslogixFileShareNames[0])) : []
var localNetAppOfficeContainerVolumeResourceIds = !empty(fslogixLocalNetAppVolumeResourceIds) && length(fslogixFileShareNames) > 1 ? filter(fslogixLocalNetAppVolumeResourceIds, id => contains(id, fslogixFileShareNames[1])) : []
var sortedLocalNetAppResourceIds = union(localNetAppProfileContainerVolumeResourceIds, localNetAppOfficeContainerVolumeResourceIds)
var remoteNetAppProfileContainerVolumeResourceIds = !empty(fslogixRemoteNetAppVolumeResourceIds) ? filter(fslogixRemoteNetAppVolumeResourceIds, id => contains(id, fslogixFileShareNames[0])) : []
var remoteNetAppOfficeContainerVolumeResourceIds = !empty(fslogixRemoteNetAppVolumeResourceIds) && length(fslogixFileShareNames) > 1 ? filter(fslogixRemoteNetAppVolumeResourceIds, id => !contains(id, fslogixFileShareNames[0])) : []
var sortedRemoteNetAppResourceIds = union(remoteNetAppProfileContainerVolumeResourceIds, remoteNetAppOfficeContainerVolumeResourceIds)

var backupPrivateDNSZoneResourceIds = [
  azureBackupPrivateDnsZoneResourceId
  azureBlobPrivateDnsZoneResourceId
  azureQueuePrivateDnsZoneResourceId
]

var nonEmptyBackupPrivateDNSZoneResourceIds = filter(backupPrivateDNSZoneResourceIds, zone => !empty(zone))

module diskAccessResource '../../../sharedModules/resources/compute/disk-access/main.bicep' = if (deployDiskAccessResource) {
  scope: resourceGroup(resourceGroupHosts)
  name: 'DiskAccess_${timeStamp}'
  params: {
    name: diskAccessName
    location: location
    privateEndpoints:[
      {
        customNetworkInterfaceName: replace(
          replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'disks'), 'RESOURCE', diskAccessName),
          'VNETID',
          '${split(privateEndpointSubnetResourceId, '/')[8]}'
        )
        name: replace(
          replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'disks'), 'RESOURCE', diskAccessName),
          'VNETID',
          '${split(privateEndpointSubnetResourceId, '/')[8]}'
        )
        privateDnsZoneGroup: empty(azureBlobPrivateDnsZoneResourceId) ? null : {
          privateDNSResourceIds: [
            azureBlobPrivateDnsZoneResourceId
          ]
        }
        service: 'disks'
        subnetResourceId: privateEndpointSubnetResourceId
        tags: tags[?'Microsoft.Network/privateEndpoints'] ?? {}
      }
    ]
    tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.Compute/diskAccesses'] ?? {})
  }
}

module diskAccessPolicy 'modules/diskNetworkAccessPolicy.bicep' = if (deployDiskAccessPolicy) {
  name: 'ManagedDisks_NetworkAccess_Policy_${timeStamp}'
  params: {
    diskAccessId: deployDiskAccessResource ? diskAccessResource.outputs.resourceId : ''
    location: location
    resourceGroupName: resourceGroupHosts
  }
}

module diskEncryption 'modules/diskEncryption.bicep' =  if (keyManagementDisks != 'PlatformManaged' || confidentialVMOSDiskEncryption) {
  name: 'DiskEncryption_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {    
    confidentialVMOrchestratorObjectId: confidentialVMOrchestratorObjectId
    confidentialVMOSDiskEncryption: confidentialVMOSDiskEncryption
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    deploymentVirtualMachineName: deploymentVirtualMachineName
    diskEncryptionSetNames: diskEncryptionSetNames
    hostPoolResourceId: hostPoolResourceId
    keyExpirationInDays: keyExpirationInDays
    keyManagementDisks: keyManagementDisks
    keyVaultNames: keyVaultNames
    keyVaultRetentionInDays: keyVaultRetentionInDays
    azureKeyVaultPrivateDnsZoneResourceId: azureKeyVaultPrivateDnsZoneResourceId
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    privateEndpoint: privateEndpoint
    privateEndpointNameConv: privateEndpointNameConv
    privateEndpointNICNameConv: privateEndpointNICNameConv
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    resourceGroupDeployment: resourceGroupDeployment
    tags: tags
    timeStamp: timeStamp
  }
}

module artifactsUserAssignedIdentity 'modules/getUserAssignedIdentity.bicep' = if(!empty(artifactsUserAssignedIdentityResourceId)) {
  name: 'ArtifactsUserAssignedIdentity_${timeStamp}'
  params: {
    userAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
  }
}

module availabilitySets '../../../sharedModules/resources/compute/availability-set/main.bicep' = [for i in range(0, availabilitySetsCount): if (pooledHostPool && availability == 'AvailabilitySets') {
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

// Role Assignment for Virtual Machine Login User
// This module deploys the role assignments to login to Azure AD joined session hosts
module roleAssignments '../../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = [for i in range(0, length(appGroupSecurityGroups)): if (!contains(identitySolution, 'DomainServices')) {
  name: 'RA-VMLoginUser-${i}_${timeStamp}'
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

@batchSize(5)
module virtualMachines 'modules/virtualMachines.bicep' = [for i in range(1, sessionHostBatchCount): {
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
    diskAccessId: deployDiskAccessResource ? diskAccessResource.outputs.resourceId : ''
    diskEncryptionSetResourceId: keyManagementDisks != 'PlatformManaged' || confidentialVMOSDiskEncryption ? diskEncryption.outputs.diskEncryptionSetResourceId : ''
    diskNamePrefix: diskNamePrefix
    diskSizeGB: diskSizeGB
    diskSku: diskSku
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
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
    storageSuffix: storageSuffix
    subnetResourceId: subnetResourceId
    tags: tags
    timeStamp: timeStamp
    useAgentDownloadEndpoint: useAgentDownloadEndpoint
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineAdminUserName: virtualMachineAdminUserName
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
    vTpmEnabled: vTpmEnabled
  }
  dependsOn: [
    availabilitySets
  ]
}]

module recoveryServicesVault '../../../sharedModules/resources/recovery-services/vault/main.bicep' = if (recoveryServices) {
  name: 'RecoveryServicesVault_VirtualMachines_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    location: location
    name: recoveryServicesVaultName
    backupPolicies: [
      {
        name: backupPolicyName
        properties: {
          backupManagementType: 'AzureIaasVM'
          instantRpRetentionRangeInDays: 2
          policyType: 'V2'
          retentionPolicy: {
            retentionPolicyType: 'LongTermRetentionPolicy'
            dailySchedule: {
              retentionDuration: {
                count: 30
                durationType: 'Days'
              }
              retentionTimes: [
                '23:00'
              ]
            }
          }
          schedulePolicy: {
            schedulePolicyType: 'SimpleSchedulePolicyV2'
            scheduleRunFrequency: 'Daily'
            dailySchedule: {
              scheduleRunTimes: [
                '23:00'
              ]
            }
          }     
          timeZone: timeZone
        }
      }
    ]
    privateEndpoints: privateEndpoint && !empty(privateEndpointSubnetResourceId) && !empty(azureBackupPrivateDnsZoneResourceId) && !empty(azureBlobPrivateDnsZoneResourceId) && !empty(azureQueuePrivateDnsZoneResourceId)
      ? [
          {
            customNetworkInterfaceName: replace(
              replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'AzureBackup'), 'RESOURCE', recoveryServicesVaultName),
              'VNETID',
              '${split(privateEndpointSubnetResourceId, '/')[8]}'
            )            
            name: replace(
              replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'AzureBackup'), 'RESOURCE', recoveryServicesVaultName),
              'VNETID',
              '${split(privateEndpointSubnetResourceId, '/')[8]}'
            )
            privateDnsZoneGroup: empty(nonEmptyBackupPrivateDNSZoneResourceIds) ? null :{
              privateDNSResourceIds: nonEmptyBackupPrivateDNSZoneResourceIds
            }
            service: 'AzureBackup'
            subnetResourceId: privateEndpointSubnetResourceId
            tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.Network/privateEndpoints'] ?? {})
          }
        ]
      : null
    diagnosticWorkspaceId: logAnalyticsWorkspaceResourceId
    tags: union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.recoveryServices/vaults'] ?? {})
  }
}

module protectedItems_Vm 'modules/protectedItems.bicep' = [for i in range(1, sessionHostBatchCount): if (recoveryServices) {
  name: 'BackupProtectedItems_VirtualMachines_${i-1}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    location: location
    PolicyId: recoveryServices ? '${recoveryServicesVault.outputs.resourceId}/backupPolicies/${backupPolicyName}' : ''
    recoveryServicesVaultName: recoveryServices ? recoveryServicesVault.outputs.name : ''
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

module getFlattenedVmNamesArray 'modules/flattenVirtualMachineNames.bicep' = {
  name: 'FlattenVirtualMachineNames_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    virtualMachineNamesPerBatch: [for i in range(1, sessionHostBatchCount):virtualMachines[i-1].outputs.virtualMachineNames]
  }
}

output virtualMachineNames array = getFlattenedVmNamesArray.outputs.virtualMachineNames
