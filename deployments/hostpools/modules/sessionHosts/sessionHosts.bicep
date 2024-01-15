targetScope = 'subscription'

param AcceleratedNetworking string
param activeDirectorySolution string
param adeKEKUrl string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param artifactsUserAssignedIdentityResourceId string
param automationAccountName string
param availability string
param availabilitySetNamePrefix string
param availabilitySetsCount int
param availabilitySetsIndex int
param availabilityZones array
param AVDInsightsLogAnalyticsWorkspaceResourceId string
param cseMasterScript string
param cseScriptAddDynParameters string
param cseUris array
param dataCollectionRulesResourceId string
param diskEncryptionOptions object
param DiskEncryptionSetResourceId string
param diskNamePrefix string
param diskSku string
param divisionRemainderValue int
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param drainMode bool
param drainModeUserAssignedIdentityClientId string
param FslogixDeployed bool
param fslogixConfigureSessionHosts bool
param fslogixExistingStorageAccountResourceIds array
param fslogixContainerType string
param hostPoolName string
param imageOffer string
param imagePublisher string
param imageSku string
param customImageResourceId string
param keyVaultResourceId string
param keyVaultUrl string
param location string
param managementVMName string
param maxResourcesPerTemplateDeployment int
param monitoring bool
param netAppFileShares array
param networkInterfaceNamePrefix string
param ouPath string
param pooledHostPool bool
param recoveryServices bool
param recoveryServicesVaultName string
param resourceGroupControlPlane string
param resourceGroupHosts string
param resourceGroupManagement string
param resourceGroupStorage string
param roleDefinitions object
param runBookUpdateUserAssignedIdentityClientId string
param scalingBeginPeakTime string
param scalingEndPeakTime string
param scalingLimitSecondsToForceLogOffUser string
param scalingMinimumNumberOfRdsh string
param scalingSessionThresholdPerCPU string
param scalingTool bool
param securityDataCollectionRulesResourceId string
param securityPrincipalObjectIds array
param securityLogAnalyticsWorkspaceResourceId string
param sessionHostBatchCount int
param sessionHostIndex int
param storageAccountPrefix string
param storageCount int
param storageIndex int
param storageSolution string
param storageSuffix string
param subnet string
param tags object
param timeDifference string
param timeStamp string
param timeZone string
param trustedLaunch string
param virtualMachineMonitoringAgent string
param virtualMachineNamePrefix string
@secure()
param virtualMachineAdminPassword string
param virtualMachineSize string
@secure()
param virtualMachineAdminUserName string
param virtualNetwork string
param virtualNetworkResourceGroup string

var tagsAutomationAccounts = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Automation/automationAccounts') ? tags['Microsoft.Automation/automationAccounts'] : {})
var tagsAvailabilitySets = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Compute/availabilitySets') ? tags['Microsoft.Compute/availabilitySets'] : {})
var tagsNetworkInterfaces = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Network/networkInterfaces') ? tags['Microsoft.Network/networkInterfaces'] : {})
var tagsRecoveryServicesVault = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.recoveryServices/vaults') ? tags['Microsoft.recoveryServices/vaults'] : {})
var tagsVirtualMachines = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {})

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
module roleAssignments '../roleAssignment.bicep' = [for i in range(0, length(securityPrincipalObjectIds)): if (!contains(activeDirectorySolution, 'DomainServices')) {
  name: 'RoleAssignments_${i}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    PrincipalId: securityPrincipalObjectIds[i]
    PrincipalType: 'Group'
    RoleDefinitionId: roleDefinitions.VirtualMachineUserLogin
  }
}]

@batchSize(1)
module virtualMachines 'virtualMachines.bicep' = [for i in range(1, sessionHostBatchCount): {
  name: 'VirtualMachines_${i - 1}_${timeStamp}'
  scope: resourceGroup(resourceGroupHosts)
  params: {
    AcceleratedNetworking: AcceleratedNetworking
    activeDirectorySolution: activeDirectorySolution
    adeKEKUrl: adeKEKUrl
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    availability: availability
    availabilityZones: availabilityZones
    availabilitySetNamePrefix: availabilitySetNamePrefix
    AVDInsightsLogAnalyticsWorkspaceResourceId: AVDInsightsLogAnalyticsWorkspaceResourceId
    BatchCount: i
    cseMasterScript: cseMasterScript
    cseScriptAddDynParameters: cseScriptAddDynParameters
    cseUris: cseUris
    dataCollectionRulesResourceId: dataCollectionRulesResourceId
    diskEncryptionOptions: diskEncryptionOptions
    DiskEncryptionSetResourceId: DiskEncryptionSetResourceId
    diskNamePrefix: diskNamePrefix
    diskSku: diskSku
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainName: domainName
    drainMode: drainMode
    drainModeUserAssignedIdentityClientId: drainModeUserAssignedIdentityClientId
    fslogixConfigureSessionHosts: fslogixConfigureSessionHosts
    fslogixContainerType: fslogixContainerType
    fslogixExistingStorageAccountResourceIds: fslogixExistingStorageAccountResourceIds
    hostPoolName: hostPoolName
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    customImageResourceId: customImageResourceId
    keyVaultResourceId: keyVaultResourceId
    keyVaultUrl: keyVaultUrl
    location: location
    managementVMName: managementVMName
    monitoring: monitoring
    netAppFileShares: netAppFileShares
    networkInterfaceNamePrefix: networkInterfaceNamePrefix
    ouPath: ouPath
    resourceGroupControlPlane: resourceGroupControlPlane
    resourceGroupManagement: resourceGroupManagement
    resourceGroupStorage: resourceGroupStorage
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    securityLogAnalyticsWorkspaceResourceId: securityLogAnalyticsWorkspaceResourceId
    sessionHostCount: i == sessionHostBatchCount && divisionRemainderValue > 0 ? divisionRemainderValue : maxResourcesPerTemplateDeployment
    sessionHostIndex: i == 1 ? sessionHostIndex : ((i - 1) * maxResourcesPerTemplateDeployment) + sessionHostIndex
    storageAccountPrefix: storageAccountPrefix
    storageCount: storageCount
    storageIndex: storageIndex
    storageSolution: storageSolution
    storageSuffix: storageSuffix
    subnet: subnet
    tagsNetworkInterfaces: tagsNetworkInterfaces
    tagsVirtualMachines: tagsVirtualMachines
    timeStamp: timeStamp
    trustedLaunch: trustedLaunch
    virtualMachineMonitoringAgent: virtualMachineMonitoringAgent
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineSize: virtualMachineSize
    virtualMachineAdminUserName: virtualMachineAdminUserName
    virtualNetwork: virtualNetwork
    virtualNetworkResourceGroup: virtualNetworkResourceGroup
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
    FslogixDeployed: FslogixDeployed
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

module scaleTool '../management/scalingTool.bicep' = if (scalingTool && pooledHostPool) {
  name: 'ScalingTool_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    artifactsUri: artifactsUri
    //artifactsStorageAccountResourceId: artifactsStorageAccountResourceId
    automationAccountName: automationAccountName
    BeginPeakTime: scalingBeginPeakTime
    EndPeakTime: scalingEndPeakTime
    hostPoolName: hostPoolName
    HostPoolResourceGroupName: resourceGroupManagement
    LimitSecondsToForceLogOffUser: scalingLimitSecondsToForceLogOffUser
    location: location
    MinimumNumberOfRdsh: scalingMinimumNumberOfRdsh
    resourceGroupHosts: resourceGroupHosts
    resourceGroupManagement: resourceGroupManagement
    runBookUpdateUserAssignedIdentityClientId: runBookUpdateUserAssignedIdentityClientId
    SessionThresholdPerCPU: scalingSessionThresholdPerCPU
    tags: tagsAutomationAccounts
    timeDifference: timeDifference
    timeZone: timeZone
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    managementVMName: managementVMName
    timeStamp: timeStamp
  }
  dependsOn: [
    recServices
  ]
}
