targetScope = 'subscription'

param avdPrivateLinkPrivateRoutes string
param envShortName string
param businessUnitIdentifier string
param centralizedAVDMonitoring bool
param existingFeedWorkspaceResourceId string
param fslogixStorageCustomPrefix string
param hostPoolIdentifier string
param locationControlPlane string
param locationGlobalFeed string
param locationVirtualMachines string
param nameConvResTypeAtEnd bool
param virtualMachineNamePrefix string

// Ensure that Centralized AVD Managment resource group and resources are created appropriately
var centralAVDMonitoring = !empty(businessUnitIdentifier) ? centralizedAVDMonitoring : true

var locations = (loadJsonContent('../../../.common/data/locations.json'))[environment().name]
var resourceAbbreviations = loadJsonContent('../../../.common/data/resourceAbbreviations.json')
// busUnitId = Identifier from MLZ AVD
var busUnitId = toLower(businessUnitIdentifier)
// hostPoolId = StampIndex from MLZ AVD
var hostPoolId = toLower(hostPoolIdentifier)

var hostPoolBaseName = !empty(busUnitId) ? '${busUnitId}-${hostPoolId}' : hostPoolId
var hostPoolPrefix = nameConvResTypeAtEnd ? hostPoolBaseName : 'RESOURCETYPE-${hostPoolBaseName}'

var nameConv_Suffix_withoutResType = !empty(envShortName) ? '${envShortName}-LOCATION' : 'LOCATION'
var nameConvSuffix = nameConvResTypeAtEnd
  ? '${nameConv_Suffix_withoutResType}-RESOURCETYPE'
  : nameConv_Suffix_withoutResType

var nameConv_HP_ResGroups = nameConvResTypeAtEnd
  ? 'avd-${hostPoolBaseName}-RESGROUPPURPOSE-${nameConvSuffix}'
  : 'RESOURCETYPE-avd-${hostPoolBaseName}-RESGROUPPURPOSE-${nameConvSuffix}'
var nameConv_HP_Resources = '${hostPoolPrefix}-${nameConvSuffix}'

// shared resources between host pools of same business unit
var nameConv_Shared_ResGroups = nameConvResTypeAtEnd
  ? (!empty(busUnitId) ? 'avd-${busUnitId}-RESGROUPPURPOSE-${nameConvSuffix}' : 'avd-RESGROUPPURPOSE-${nameConvSuffix}')
  : (!empty(busUnitId)
      ? 'RESOURCETYPE-avd-${busUnitId}-RESGROUPPURPOSE-${nameConvSuffix}'
      : 'RESOURCETYPE-avd-RESGROUPPURPOSE-${nameConvSuffix}')
var nameConv_Shared_Resources = nameConvResTypeAtEnd
  ? (!empty(busUnitId) ? '${busUnitId}-${nameConvSuffix}' : '${nameConvSuffix}')
  : (!empty(busUnitId) ? 'RESOURCETYPE-${busUnitId}-${nameConvSuffix}' : 'RESOURCETYPE-${nameConvSuffix}')

// monitoring resources
var nameConv_Monitoring_ResGroup = centralAVDMonitoring
  ? (nameConvResTypeAtEnd
      ? 'avd-RESGROUPPURPOSE-${nameConvSuffix}'
      : 'RESOURCETYPE-avd-RESGROUPPURPOSE-${nameConvSuffix}')
  : nameConv_Shared_ResGroups
var nameConv_Monitoring_Resources = centralAVDMonitoring
  ? (nameConvResTypeAtEnd ? 'avd-${nameConvSuffix}' : 'RESOURCETYPE-avd-${nameConvSuffix}')
  : (nameConvResTypeAtEnd
      ? (!empty(busUnitId) ? '${busUnitId}-avd-${nameConvSuffix}' : 'avd-${nameConvSuffix}')
      : (!empty(busUnitId) ? 'RESOURCETYPE-${busUnitId}-avd-${nameConvSuffix}' : 'RESOURCETYPE-avd-${nameConvSuffix}'))

// Global Feed Resources
var globalFeedResourceGroupName = avdPrivateLinkPrivateRoutes == 'All' && !(empty(locationGlobalFeed))
  ? replace(
      replace(
        (nameConvResTypeAtEnd ? 'avd-global-feed-${nameConvSuffix}' : 'RESOURCETYPE-avd-global-feed-${nameConvSuffix}'),
        'LOCATION',
        '${locations[locationGlobalFeed].abbreviation}'
      ),
      'RESOURCETYPE',
      '${resourceAbbreviations.resourceGroups}'
    )
  : ''
var globalFeedWorkspaceName = avdPrivateLinkPrivateRoutes == 'All'
  ? replace(
      (nameConvResTypeAtEnd ? 'avd-global-feed-RESOURCETYPE' : 'RESOURCETYPE-avd-global-feed'),
      'RESOURCETYPE',
      resourceAbbreviations.workspaces
    )
  : ''

// Control Plane HostPool Resources
var desktopApplicationGroupName = replace(
  replace('${hostPoolPrefix}-${nameConvSuffix}', 'RESOURCETYPE', resourceAbbreviations.desktopApplicationGroups),
  'LOCATION',
  locations[locationControlPlane].abbreviation
)
var hostPoolName = replace(
  replace('${hostPoolPrefix}-${nameConvSuffix}', 'RESOURCETYPE', resourceAbbreviations.hostPools),
  'LOCATION',
  locations[locationControlPlane].abbreviation
)
var scalingPlanName = replace(
  replace('${hostPoolPrefix}-${nameConvSuffix}', 'RESOURCETYPE', resourceAbbreviations.scalingPlans),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)

// Control Plane Shared Resources
var resourceGroupControlPlane = empty(existingFeedWorkspaceResourceId) ? replace(
  replace(
    replace(nameConv_Shared_ResGroups, 'RESGROUPPURPOSE', 'control-plane'),
    'LOCATION',
    '${locations[locationControlPlane].abbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
) : split(existingFeedWorkspaceResourceId, '/')[4]

var workspaceName = empty(existingFeedWorkspaceResourceId) ? replace(
  replace(nameConv_Shared_Resources, 'RESOURCETYPE', resourceAbbreviations.workspaces),
  'LOCATION',
  locations[locationControlPlane].abbreviation
) : last(split(existingFeedWorkspaceResourceId, '/'))

// Compute Resources
var resourceGroupHosts = replace(
  replace(
    replace(nameConv_HP_ResGroups, 'RESGROUPPURPOSE', 'hosts'),
    'LOCATION',
    '${locations[locationVirtualMachines].abbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
)
var availabilitySetNamePrefix = nameConvResTypeAtEnd
  ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.availabilitySets}-'
  : '${resourceAbbreviations.availabilitySets}-${vmNamePrefixWithoutDash}-'
var vmNamePrefixWithoutDash = last(virtualMachineNamePrefix) == '-'
  ? take(virtualMachineNamePrefix, length(virtualMachineNamePrefix) - 1)
  : virtualMachineNamePrefix
var diskNamePrefix = nameConvResTypeAtEnd
  ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.disks}-'
  : '${resourceAbbreviations.disks}-${vmNamePrefixWithoutDash}-'
var networkInterfaceNamePrefix = nameConvResTypeAtEnd
  ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.networkInterfaces}-'
  : '${resourceAbbreviations.networkInterfaces}-${vmNamePrefixWithoutDash}-'

// Management Resources
var resourceGroupManagement = replace(
  replace(
    replace(nameConv_HP_ResGroups, 'RESGROUPPURPOSE', 'management'),
    'LOCATION',
    '${locations[locationVirtualMachines].abbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
)
var automationAccountName = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.automationAccounts),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)
var diskAccessName = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.diskAccesses),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)
// Disk Encryption Set Names - Max length 80 Characters
var diskEncryptionSetNameConv = replace(
  replace('${hostPoolPrefix}-DESTYPE-${nameConvSuffix}', 'RESOURCETYPE', resourceAbbreviations.diskEncryptionSets),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)
var diskEncryptionSetConfVms = replace(diskEncryptionSetNameConv, 'DESTYPE-', 'confvm-customer-key-')
var diskEncryptionSetCustKeysName = replace(diskEncryptionSetNameConv, 'DESTYPE-', 'customer-key-')
var diskEncryptionSetPlatAndCustKeysName = replace(diskEncryptionSetNameConv, 'DESTYPE-', 'platform-and-customer-keys-')

// Key Vault Names - Max length 24 characters
var keyVaultNameConv = replace(
  replace('${hostPoolPrefix}-KEYVAULTPURPOSE-INDEX-${nameConvSuffix}', 'RESOURCETYPE', resourceAbbreviations.keyVaults),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)
var keyVaultNameVMs = length(replace(replace(keyVaultNameConv, 'KEYVAULTPURPOSE-', 'vm-'), 'INDEX-', '')) > 24
  ? replace(replace(replace(keyVaultNameConv, 'KEYVAULTPURPOSE-', 'vm-'), 'INDEX-', ''), '-', '')
  : replace(replace(keyVaultNameConv, 'KEYVAULTPURPOSE-', 'vm-'), 'INDEX-', '')
var keyVaultNameConvStorage = length(replace(keyVaultNameConv, 'KEYVAULTPURPOSE-', 'st-')) > 27
  ? replace(replace(keyVaultNameConv, 'KEYVAULTPURPOSE-', 'st-'), '-', '')
  : replace(keyVaultNameConv, 'KEYVAULTPURPOSE-', 'st-')

var recoveryServicesVaultName = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.recoveryServicesVaults),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)

var userAssignedIdentityNameConv = replace(
  replace(
    '${hostPoolPrefix}-UAIPURPOSE-${nameConvSuffix}',
    'RESOURCETYPE',
    resourceAbbreviations.userAssignedIdentities
  ),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)

var mgmtVirtualMachineName = replace(
  replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', ''),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  '-',
  ''
)
var mgmtVirtualMachineDiskName = nameConvResTypeAtEnd
  ? '${mgmtVirtualMachineName}-${resourceAbbreviations.disks}'
  : '${resourceAbbreviations.disks}-${mgmtVirtualMachineName}'
var mgmtVirtualMachineNicName = nameConvResTypeAtEnd
  ? '${mgmtVirtualMachineName}-${resourceAbbreviations.networkInterfaces}'
  : '${resourceAbbreviations.networkInterfaces}-${mgmtVirtualMachineName}'

// Storage Resources
var resourceGroupStorage = replace(
  replace(
    replace(nameConv_HP_ResGroups, 'RESGROUPPURPOSE', 'storage'),
    'LOCATION',
    '${locations[locationVirtualMachines].abbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
)
var netAppAccountName = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.netAppAccounts),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)
var netAppCapacityPoolName = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.netAppCapacityPools),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)
// Storage Account Naming Prefix
var storageAccountNamePrefix = empty(fslogixStorageCustomPrefix)
  ? toLower('${replace(replace(replace(replace(replace(nameConv_HP_Resources, 'RESOURCETYPE', ''), hostPoolBaseName, '${hostPoolBaseName}ud'), 'LOCATION', locations[locationVirtualMachines].abbreviation), 'avd-', ''), '-', '')}')
  : toLower(fslogixStorageCustomPrefix)

var fslogixfileShareNames = {
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
// Private Endpoints - Max length 64 characters
var privateEndpointNameConvTemp = nameConvResTypeAtEnd
  ? 'RESOURCE-SUBRESOURCE-VNETID-RESOURCETYPE'
  : 'RESOURCETYPE-RESOURCE-SUBRESOURCE-VNETID'
var privateEndpointNameConv = replace(
  privateEndpointNameConvTemp,
  'RESOURCETYPE',
  resourceAbbreviations.privateEndpoints
)
var privateEndpointNICNameConvTemp = nameConvResTypeAtEnd
  ? '${privateEndpointNameConv}-RESOURCETYPE'
  : 'RESOURCETYPE-${privateEndpointNameConv}'
var privateEndpointNICNameConv = replace(
  privateEndpointNICNameConvTemp,
  'RESOURCETYPE',
  resourceAbbreviations.networkInterfaces
)

// Monitoring Resources
var resourceGroupMonitoring = replace(
  replace(
    replace(nameConv_Monitoring_ResGroup, 'RESGROUPPURPOSE', 'monitoring'),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'RESOURCETYPE',
  resourceAbbreviations.resourceGroups
)
var dataCollectionEndpointName = replace(
  replace(nameConv_Monitoring_Resources, 'RESOURCETYPE', resourceAbbreviations.dataCollectionEndpoints),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)
// the AVD Insights data collection rule must start with 'microsoft-avdi-'
var dataCollectionRulesNameConv = replace(
  replace(nameConv_Monitoring_Resources, 'RESOURCETYPE', resourceAbbreviations.dataCollectionRules),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)

var logAnalyticsWorkspaceName = replace(
  replace(nameConv_Monitoring_Resources, 'RESOURCETYPE', resourceAbbreviations.logAnalyticsWorkspaces),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)

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
output fslogixFileShareNames object = fslogixfileShareNames
output hostPoolName string = hostPoolName
output keyVaultNames object = {
  VMs: keyVaultNameVMs
  StorageAccounts: keyVaultNameConvStorage
}
output locations object = locations
output logAnalyticsWorkspaceName string = logAnalyticsWorkspaceName
output netAppAccountName string = netAppAccountName
output netAppCapacityPoolName string = netAppCapacityPoolName
output networkInterfaceNamePrefix string = networkInterfaceNamePrefix
output privateEndpointNameConv string = privateEndpointNameConv
output privateEndpointNICNameConv string = privateEndpointNICNameConv
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
