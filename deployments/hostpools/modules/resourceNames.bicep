targetScope = 'subscription'

param environmentShortName string
param businessUnitIdentifier string
param centralizedAVDMonitoring bool
param fslogixStorageCustomPrefix string
param hostPoolIdentifier string
param locationControlPlane string
param locationVirtualMachines string
param nameConvResTypeAtEnd bool
param virtualMachineNamePrefix string

// Ensure that Centralized AVD Managment resource group and resources are created appropriately
var centralAVDMonitoring = !empty(businessUnitIdentifier) ? centralizedAVDMonitoring : true

var fileShareNames = {
  CloudCacheProfileContainer: [
    'profile-containers'
  ]
  CloudCacheProfileOfficeContainer: [
    'profile-containers'
    'office-containers'
  ]
  ProfileContainer: [
    'profile-containers'
  ]
  ProfileOfficeContainer: [
    'profile-containers'
    'office-containers'
  ]
}

var locations = loadJsonContent('../../../.common/data/locations.json')
var resourceAbbreviations = loadJsonContent('../../../.common/data/resourceAbbreviations.json')
// automatically add 'avd-' prefix to the prefix if it isn't already listed.
// businessUnitId = Identifier from MLZ AVD
var businessUnitId = !empty(businessUnitIdentifier) ? contains(businessUnitIdentifier, 'avd') ? businessUnitIdentifier : '${businessUnitIdentifier}-avd' : ''
// hostPoolId = StampIndex from MLZ AVD
var hostPoolId = !empty(businessUnitIdentifier) ? hostPoolIdentifier : ( contains(hostPoolIdentifier, 'avd') ? hostPoolIdentifier : 'avd-${hostPoolIdentifier}' )

var hostPoolBaseName = !empty(businessUnitIdentifier) ? '${businessUnitId}-${hostPoolId}' : hostPoolId
var hostPoolPrefix = nameConvResTypeAtEnd ? hostPoolBaseName : 'resourceType-${hostPoolBaseName}'

var nameConv_Suffix_withoutResType = !empty(environmentShortName) ? '${environmentShortName}-location' : 'location'
var nameConvSuffix = nameConvResTypeAtEnd ? '${nameConv_Suffix_withoutResType}-resourceType' : nameConv_Suffix_withoutResType

var nameConv_HP_ResGroups = '${hostPoolPrefix}-resGroupPurpose-${nameConvSuffix}'
var nameConv_HP_Resources = '${hostPoolPrefix}-${nameConvSuffix}'

// shared resources between host pools of same business unit
var nameConv_Shared_ResGroups = nameConvResTypeAtEnd ? ( !empty(businessUnitIdentifier) ? '${businessUnitId}-resGroupPurpose-${nameConvSuffix}' : 'avd-resGroupPurpose-${nameConvSuffix}' ) : ( !empty(businessUnitIdentifier) ? 'resourceType-${businessUnitId}-resGroupPurpose-${nameConvSuffix}' : 'resourceType-avd-resGroupPurpose-${nameConvSuffix}' )
var nameConv_Shared_Resources = nameConvResTypeAtEnd ? ( !empty(businessUnitIdentifier) ? '${businessUnitId}-${nameConvSuffix}' : '${nameConvSuffix}' ) : (!empty(businessUnitId) ? 'resourceType-${businessUnitId}-${nameConvSuffix}' : 'resourceType-${nameConvSuffix}' )

// monitoring resources
var nameConv_Monitoring_ResGroup = centralAVDMonitoring ? ( nameConvResTypeAtEnd ? 'avd-resGroupPurpose-${nameConvSuffix}' : 'resourceType-avd-resGroupPurpose-${nameConvSuffix}' ) : nameConv_Shared_ResGroups
var nameConv_Monitoring_Resources = centralAVDMonitoring ? ( nameConvResTypeAtEnd ? 'avd-${nameConvSuffix}' : 'resourceType-avd-${nameConvSuffix}' ) : nameConv_Shared_Resources

// Global Feed Resources
var globalFeedResourceGroupName = replace(replace(replace((nameConvResTypeAtEnd ? 'avd-resGroupPurpose-${nameConvSuffix}' : 'resourceType-avd-resGroupPurpose-${nameConvSuffix}'), 'resGroupPurpose', 'global-feed'), 'location', '${locations[locationVirtualMachines].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var globalFeedWorkspaceName = replace((nameConvResTypeAtEnd ? 'avd-feed-global-resourceType' : 'resourceType-avd-feed-global'), 'resourceType', resourceAbbreviations.workspaces)

// Compute Resources
var resourceGroupHosts = replace(replace(replace(nameConv_HP_ResGroups, 'resGroupPurpose', 'hosts'), 'location', '${locations[locationControlPlane].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var availabilitySetNamePrefix = nameConvResTypeAtEnd ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.availabilitySets}-' : '${resourceAbbreviations.availabilitySets}-${vmNamePrefixWithoutDash}-'
var vmNamePrefixWithoutDash = last(virtualMachineNamePrefix) == '-' ? take(virtualMachineNamePrefix, length(virtualMachineNamePrefix) - 1) : virtualMachineNamePrefix
var diskNamePrefix = nameConvResTypeAtEnd ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.disks}-' : '${resourceAbbreviations.disks}-${vmNamePrefixWithoutDash}-'
var networkInterfaceNamePrefix = nameConvResTypeAtEnd ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.networkInterfaces}-' : '${resourceAbbreviations.networkInterfaces}-${vmNamePrefixWithoutDash}-'

// Management Resources
var resourceGroupManagement = replace(replace(replace(nameConv_HP_ResGroups, 'resGroupPurpose', 'management'), 'location', '${locations[locationVirtualMachines].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var automationAccountName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.automationAccounts), 'location', locations[locationVirtualMachines].abbreviation)
var diskAccessName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.diskAccesses), 'location', locations[locationVirtualMachines].abbreviation)
var diskEncryptionSetNameConv = replace(replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.diskEncryptionSets), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', 'desType-')
var diskEncryptionSetConfVms = replace(diskEncryptionSetNameConv, 'desType-', 'confvm-')
var diskEncryptionSetCustKeysName = replace(diskEncryptionSetNameConv, 'desType-', 'vmcustkeys-')
var diskEncryptionSetPlatAndCustKeysName = replace(diskEncryptionSetNameConv, 'desType-', 'vmplatcustkeys-')
var keyVaultNameConv = replace(replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.keyVaults), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', 'keyVaultPurpose-')
var keyVaultNameSecrets = replace(keyVaultNameConv, 'keyVaultPurpose-', 'sec-')
var keyVaultNameStandardKeys = replace(keyVaultNameConv, 'keyVaultPurpose-', 'ekeys-')
var keyVaultNameConfVMKeys = replace(keyVaultNameConv, 'keyVaultPurpose-', 'cekeys-')
var recoveryServicesVaultName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.recoveryServicesVaults), 'location', locations[locationVirtualMachines].abbreviation)
var userAssignedIdentityNameConv = replace(replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.userAssignedIdentities), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', 'avd-uaiPurpose-')
var mgmtVirtualMachineName = replace(replace(replace(replace(nameConv_HP_Resources, 'resourceType', ''), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', 'avdmgmt'), '-', '')
var mgmtVirtualMachineDiskName = nameConvResTypeAtEnd ? '${mgmtVirtualMachineName}-${resourceAbbreviations.disks}' : '${resourceAbbreviations.disks}-${mgmtVirtualMachineName}'
var mgmtVirtualMachineNicName = nameConvResTypeAtEnd ? '${mgmtVirtualMachineName}-${resourceAbbreviations.networkInterfaces}' : '${resourceAbbreviations.networkInterfaces}-${mgmtVirtualMachineName}'

// Storage Resources
var resourceGroupStorage = replace(replace(replace(nameConv_HP_ResGroups, 'resGroupPurpose', 'storage'), 'location', '${locations[locationVirtualMachines].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var netAppAccountName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.netAppAccounts), 'location', locations[locationVirtualMachines].abbreviation)
var netAppCapacityPoolName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.netAppCapacityPools), 'location', locations[locationVirtualMachines].abbreviation)
var storageAccountNamePrefix = empty(fslogixStorageCustomPrefix) ? toLower('${replace(replace(replace(replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.storageAccounts), hostPoolBaseName, '${hostPoolBaseName}fsl'), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', ''), '-', '')}') : fslogixStorageCustomPrefix
var privateEndpointNameConv = replace('${nameConvResTypeAtEnd ? 'resource-subresource-resourceType' : 'resourceType-resource-subresource'}', 'resourceType', resourceAbbreviations.privateEndpoints)

// Control Plane Resources
var resourceGroupControlPlane = replace(replace(replace(nameConv_Shared_ResGroups, 'resGroupPurpose', 'controlplane'), 'location', '${locations[locationControlPlane].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var workspaceName = replace(replace(nameConv_Shared_Resources, 'resourceType', resourceAbbreviations.workspaces), 'location', locations[locationControlPlane].abbreviation)
var desktopApplicationGroupName = replace(replace(nameConv_Shared_Resources, 'resourceType', resourceAbbreviations.desktopApplicationGroups), 'location', locations[locationControlPlane].abbreviation)
var hostPoolName = replace(replace(nameConv_Shared_Resources, 'resourceType', resourceAbbreviations.hostPools), 'location', locations[locationControlPlane].abbreviation)

// Monitoring Resources
var resourceGroupMonitoring = replace(replace(replace(nameConv_Monitoring_ResGroup, 'resGroupPurpose', 'monitoring'), 'location', locations[locationVirtualMachines].abbreviation), 'resourceType', resourceAbbreviations.resourceGroups)
var dataCollectionEndpointName = replace(replace(nameConv_Monitoring_Resources, 'resourceType', resourceAbbreviations.dataCollectionEndpoints), 'location', locations[locationVirtualMachines].abbreviation)
// the AVD Insights data collection rule must start with 'microsoft-avdi-'
var dataCollectionRulesNameConv = replace(replace(replace(nameConv_Monitoring_Resources, 'resourceType', resourceAbbreviations.dataCollectionRules), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', '')
var logAnalyticsWorkspaceName = replace(replace(nameConv_Monitoring_Resources, 'resourceType', resourceAbbreviations.logAnalyticsWorkspaces), 'location', locations[locationVirtualMachines].abbreviation)

output availabilitySetNamePrefix string = availabilitySetNamePrefix
output automationAccountName string = automationAccountName
output dataCollectionEndpointName string = dataCollectionEndpointName
output dataCollectionRulesNameConv string = dataCollectionRulesNameConv
output desktopApplicationGroupName string = desktopApplicationGroupName
output diskAccessName string = diskAccessName
output diskEncryptionSetNames object = {
  ConfidentialVMs: diskEncryptionSetConfVms
  CustomerManaged: diskEncryptionSetCustKeysName
  PlatformAndCustomerManaged: diskEncryptionSetPlatAndCustKeysName
}
output diskNamePrefix string = diskNamePrefix
output globalFeedWorkspaceName string = globalFeedWorkspaceName
output fileShareNames object = fileShareNames
output hostPoolName string = hostPoolName
output keyVaultNames object = {
  RSAHSMKeys: keyVaultNameConfVMKeys
  VMSecrets: keyVaultNameSecrets
  RSAKeys: keyVaultNameStandardKeys
}
output locations object = locations
output logAnalyticsWorkspaceName string = logAnalyticsWorkspaceName
output netAppAccountName string = netAppAccountName
output netAppCapacityPoolName string = netAppCapacityPoolName
output networkInterfaceNamePrefix string = networkInterfaceNamePrefix
output privateEndpointNameConv string = privateEndpointNameConv
output recoveryServicesVaultName string = recoveryServicesVaultName
output resourceGroupControlPlane string = resourceGroupControlPlane
output resourceGroupGlobalFeed string = globalFeedResourceGroupName
output resourceGroupHosts string = resourceGroupHosts
output resourceGroupManagement string = resourceGroupManagement
output resourceGroupMonitoring string = resourceGroupMonitoring
output resourceGroupStorage string = resourceGroupStorage
output storageAccountNamePrefix string = storageAccountNamePrefix
output userAssignedIdentityNameConv string = userAssignedIdentityNameConv
output virtualMachineNamePrefix string = virtualMachineNamePrefix
output mgmtVirtualMachineName string = mgmtVirtualMachineName
output mgmtVirtualMachineNicName string = mgmtVirtualMachineNicName
output mgmtVirtualMachineDiskName string = mgmtVirtualMachineDiskName
output workspaceName string = workspaceName
