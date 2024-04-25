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

var locations = (loadJsonContent('../../../.common/data/locations.json'))[environment().name]
var resourceAbbreviations = loadJsonContent('../../../.common/data/resourceAbbreviations.json')
// automatically add 'avd-' prefix to the prefix if it isn't already listed.
// busUnitId = Identifier from MLZ AVD
var busUnitId = toLower(businessUnitIdentifier) 
// hostPoolId = StampIndex from MLZ AVD
var hostPoolId = toLower(hostPoolIdentifier)

var hostPoolBaseName = !empty(busUnitId) ? '${busUnitId}-${hostPoolId}' : hostPoolId
var hostPoolPrefix = nameConvResTypeAtEnd ? hostPoolBaseName : 'resourceType-${hostPoolBaseName}'

var nameConv_Suffix_withoutResType = !empty(environmentShortName) ? '${environmentShortName}-location' : 'location'
var nameConvSuffix = nameConvResTypeAtEnd ? '${nameConv_Suffix_withoutResType}-resourceType' : nameConv_Suffix_withoutResType

var nameConv_HP_ResGroups = '${hostPoolPrefix}-resGroupPurpose-${nameConvSuffix}'
var nameConv_HP_Resources = '${hostPoolPrefix}-${nameConvSuffix}'

// shared resources between host pools of same business unit
var nameConv_Shared_ResGroups = nameConvResTypeAtEnd ? ( !empty(busUnitId) ? '${busUnitId}-resGroupPurpose-${nameConvSuffix}' : 'resGroupPurpose-${nameConvSuffix}' ) : ( !empty(busUnitId) ? 'resourceType-${busUnitId}-resGroupPurpose-${nameConvSuffix}' : 'resourceType-resGroupPurpose-${nameConvSuffix}' )
var nameConv_Shared_Resources = nameConvResTypeAtEnd ? ( !empty(busUnitId) ? '${busUnitId}-${nameConvSuffix}' : '${nameConvSuffix}' ) : (!empty(busUnitId) ? 'resourceType-${busUnitId}-${nameConvSuffix}' : 'resourceType-${nameConvSuffix}' )

// monitoring resources
var nameConv_Monitoring_ResGroup = centralAVDMonitoring ? ( nameConvResTypeAtEnd ? 'resGroupPurpose-${nameConvSuffix}' : 'resourceType-resGroupPurpose-${nameConvSuffix}' ) : nameConv_Shared_ResGroups
var nameConv_Monitoring_Resources = centralAVDMonitoring ? ( nameConvResTypeAtEnd ? 'avd-${nameConvSuffix}' : 'resourceType-avd-${nameConvSuffix}' ) : ( nameConvResTypeAtEnd ? ( !empty(busUnitId) ? '${busUnitId}-avd-${nameConvSuffix}' : 'avd-${nameConvSuffix}' ) : ( !empty(busUnitId) ? 'resourceType-${busUnitId}-avd-${nameConvSuffix}' : 'resourceType-avd-${nameConvSuffix}' ) )

// Global Feed Resources
var globalFeedResourceGroupName = replace(replace((nameConvResTypeAtEnd ? 'avd-global-feed-${nameConvSuffix}' : 'resourceType-avd-global-feed-${nameConvSuffix}'), 'location', '${locations[locationVirtualMachines].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var globalFeedWorkspaceName = replace((nameConvResTypeAtEnd ? 'avd-global-feed-resourceType' : 'resourceType-avd-global-feed'), 'resourceType', resourceAbbreviations.workspaces)

// Control Plane HostPool Resources
var desktopApplicationGroupName = replace(replace('${hostPoolPrefix}-${nameConvSuffix}', 'resourceType', resourceAbbreviations.desktopApplicationGroups), 'location', locations[locationControlPlane].abbreviation)
var hostPoolName = replace(replace('${hostPoolPrefix}-${nameConvSuffix}', 'resourceType', resourceAbbreviations.hostPools), 'location', locations[locationControlPlane].abbreviation)
var scalingPlanName = replace(replace('${hostPoolPrefix}-${nameConvSuffix}', 'resourceType', resourceAbbreviations.scalingPlans), 'location', locations[locationVirtualMachines].abbreviation)

// Control Plane Business Unit Resources
var resourceGroupControlPlane = replace(replace(replace(nameConv_Shared_ResGroups, 'resGroupPurpose', 'avd-controlplane'), 'location', '${locations[locationControlPlane].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var workspaceName = replace(replace(nameConv_Shared_Resources, 'resourceType', resourceAbbreviations.workspaces), 'location', locations[locationControlPlane].abbreviation)

// Compute Resources
var resourceGroupHosts = replace(replace(replace(nameConv_HP_ResGroups, 'resGroupPurpose', 'avd-hosts'), 'location', '${locations[locationControlPlane].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var availabilitySetNamePrefix = nameConvResTypeAtEnd ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.availabilitySets}-' : '${resourceAbbreviations.availabilitySets}-${vmNamePrefixWithoutDash}-'
var vmNamePrefixWithoutDash = last(virtualMachineNamePrefix) == '-' ? take(virtualMachineNamePrefix, length(virtualMachineNamePrefix) - 1) : virtualMachineNamePrefix
var diskNamePrefix = nameConvResTypeAtEnd ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.disks}-' : '${resourceAbbreviations.disks}-${vmNamePrefixWithoutDash}-'
var networkInterfaceNamePrefix = nameConvResTypeAtEnd ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.networkInterfaces}-' : '${resourceAbbreviations.networkInterfaces}-${vmNamePrefixWithoutDash}-'

// Management Resources
var resourceGroupManagement = replace(replace(replace(nameConv_HP_ResGroups, 'resGroupPurpose', 'avd-management'), 'location', '${locations[locationVirtualMachines].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var automationAccountName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.automationAccounts), 'location', locations[locationVirtualMachines].abbreviation)
var diskAccessName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.diskAccesses), 'location', locations[locationVirtualMachines].abbreviation)
var diskEncryptionSetNameConv = replace(replace('${hostPoolPrefix}-desType-${nameConvSuffix}', 'resourceType', resourceAbbreviations.diskEncryptionSets), 'location', locations[locationVirtualMachines].abbreviation)
var diskEncryptionSetConfVms = replace(diskEncryptionSetNameConv, 'desType-', 'confvm-')
var diskEncryptionSetCustKeysName = replace(diskEncryptionSetNameConv, 'desType-', 'vmcustkeys-')
var diskEncryptionSetPlatAndCustKeysName = replace(diskEncryptionSetNameConv, 'desType-', 'vmplatcustkeys-')

var keyVaultNameConv = replace(replace('${hostPoolPrefix}-keyVaultPurpose-${nameConvSuffix}', 'resourceType', resourceAbbreviations.keyVaults), 'location', locations[locationVirtualMachines].abbreviation)
var keyVaultNameSecrets = length(replace(keyVaultNameConv, 'keyVaultPurpose-', 'sec-')) > 24 ? replace(replace(keyVaultNameConv, 'keyVaultPurpose-', 'sec-'), '-', '') : replace(keyVaultNameConv, 'keyVaultPurpose-', 'sec-') 
var keyVaultNameStandardKeys = length(replace(keyVaultNameConv, 'keyVaultPurpose-', 'ekeys-')) > 24 ? replace(replace(keyVaultNameConv, 'keyVaultPurpose-', 'ekeys-'), '-', '') : replace(keyVaultNameConv, 'keyVaultPurpose-', 'ekeys-')
var keyVaultNameConfVMKeys = length(replace(keyVaultNameConv, 'keyVaultPurpose-', 'cekeys-')) > 24 ? replace(replace(keyVaultNameConv, 'keyVaultPurpose-', 'cekeys-'), '-', '') : replace(keyVaultNameConv, 'keyVaultPurpose-', 'cekeys-')

var recoveryServicesVaultName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.recoveryServicesVaults), 'location', locations[locationVirtualMachines].abbreviation)

var userAssignedIdentityNameConv = replace(replace('${hostPoolPrefix}-uaiPurpose-${nameConvSuffix}', 'resourceType', resourceAbbreviations.userAssignedIdentities), 'location', locations[locationVirtualMachines].abbreviation)

var mgmtVirtualMachineName = replace(replace(replace(nameConv_HP_Resources, 'resourceType', ''), 'location', locations[locationVirtualMachines].abbreviation), '-', '')
var mgmtVirtualMachineDiskName = nameConvResTypeAtEnd ? '${mgmtVirtualMachineName}-${resourceAbbreviations.disks}' : '${resourceAbbreviations.disks}-${mgmtVirtualMachineName}'
var mgmtVirtualMachineNicName = nameConvResTypeAtEnd ? '${mgmtVirtualMachineName}-${resourceAbbreviations.networkInterfaces}' : '${resourceAbbreviations.networkInterfaces}-${mgmtVirtualMachineName}'

// Storage Resources
var resourceGroupStorage = replace(replace(replace(nameConv_HP_ResGroups, 'resGroupPurpose', 'avd-storage'), 'location', '${locations[locationVirtualMachines].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var netAppAccountName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.netAppAccounts), 'location', locations[locationVirtualMachines].abbreviation)
var netAppCapacityPoolName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.netAppCapacityPools), 'location', locations[locationVirtualMachines].abbreviation)
var storageAccountNamePrefix = empty(fslogixStorageCustomPrefix) ? toLower('${replace(replace(replace(replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.storageAccounts), hostPoolBaseName, '${hostPoolBaseName}fsl'), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', ''), '-', '')}') : toLower(fslogixStorageCustomPrefix)

// Private Endpoints
var privateEndpointNameConv = replace('${nameConvResTypeAtEnd ? 'resource-subresource-resourceType-uniqueString' : 'resourceType-resource-subresource-uniqueString'}', 'resourceType', resourceAbbreviations.privateEndpoints)

// Monitoring Resources
var resourceGroupMonitoring = replace(replace(replace(nameConv_Monitoring_ResGroup, 'resGroupPurpose', 'avd-monitoring'), 'location', locations[locationVirtualMachines].abbreviation), 'resourceType', resourceAbbreviations.resourceGroups)
var dataCollectionEndpointName = replace(replace(nameConv_Monitoring_Resources, 'resourceType', resourceAbbreviations.dataCollectionEndpoints), 'location', locations[locationVirtualMachines].abbreviation)
// the AVD Insights data collection rule must start with 'microsoft-avdi-'
var dataCollectionRulesNameConv = replace(replace(nameConv_Monitoring_Resources, 'resourceType', resourceAbbreviations.dataCollectionRules), 'location', locations[locationVirtualMachines].abbreviation)

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
output scalingPlanName string = scalingPlanName
output storageAccountNamePrefix string = storageAccountNamePrefix
output userAssignedIdentityNameConv string = userAssignedIdentityNameConv
output virtualMachineNamePrefix string = virtualMachineNamePrefix
output mgmtVirtualMachineName string = mgmtVirtualMachineName
output mgmtVirtualMachineNicName string = mgmtVirtualMachineNicName
output mgmtVirtualMachineDiskName string = mgmtVirtualMachineDiskName
output workspaceName string = workspaceName
