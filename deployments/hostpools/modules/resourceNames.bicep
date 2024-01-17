targetScope = 'subscription'

param environmentShortName string
param businessUnitIdentifier string
param centralizedAVDManagement bool
param fslogixStorageCustomPrefix string
param hostPoolIdentifier string
param locationControlPlane string
param locationVirtualMachines string
param nameConvResTypeAtEnd bool
param virtualMachineNamePrefix string

// Ensure that Centralized AVD Managment resource group and resources are created appropriately
var centralAVDManagement = !empty(businessUnitIdentifier) ? centralizedAVDManagement : true

var fileShareNames = {
  CloudCacheProfileContainer: [
    'profile-containers'
  ]
  CloudCacheProfileOfficeContainer: [
    'office-containers'
    'profile-containers'
  ]
  ProfileContainer: [
    'profile-containers'
  ]
  ProfileOfficeContainer: [
    'office-containers'
    'profile-containers'
  ]
}

var locations = loadJsonContent('../../../.common/data/locations.json')
var resourceAbbreviations = loadJsonContent('../../../.common/data/resourceAbbreviations.json')
// automatically add 'avd-' prefix to the prefix if it isn't already listed.
var businessUnitId = !empty(businessUnitIdentifier) ? contains(businessUnitIdentifier, 'avd') ? businessUnitIdentifier : '${businessUnitIdentifier}-avd' : ''
var hostPoolId = !empty(businessUnitIdentifier) ? hostPoolIdentifier : ( contains(hostPoolIdentifier, 'avd') ? hostPoolIdentifier : 'avd-${hostPoolIdentifier}' )

var hostPoolBaseName = !empty(businessUnitIdentifier) ? '${businessUnitId}-${hostPoolId}' : hostPoolId
var hostPoolPrefix = nameConvResTypeAtEnd ? hostPoolBaseName : 'resourceType-${hostPoolBaseName}'

var nameConv_Suffix_withoutResType = !empty(environmentShortName) ? '${environmentShortName}-location' : 'location'
var nameConvSuffix = nameConvResTypeAtEnd ? '${nameConv_Suffix_withoutResType}-resourceType' : nameConv_Suffix_withoutResType

var nameConv_HP_ResGroups = '${hostPoolPrefix}-resGroupPurpose-${nameConvSuffix}'
var nameConv_HP_Resources = '${hostPoolPrefix}-${nameConvSuffix}'

var nameConv_Shared_ResGroups = nameConvResTypeAtEnd ? ( !empty(businessUnitIdentifier) ? '${businessUnitId}-resGroupPurpose-${nameConvSuffix}' : 'avd-resGroupPurpose-${nameConvSuffix}' ) : ( !empty(businessUnitIdentifier) ? 'resourceType-${businessUnitId}-resGroupPurpose-${nameConvSuffix}' : 'resourceType-avd-resGroupPurpose-${nameConvSuffix}' )
var nameConv_Shared_Resources = nameConvResTypeAtEnd ? ( !empty(businessUnitIdentifier) ? '${businessUnitId}-${nameConvSuffix}' : '${nameConvSuffix}' ) : (!empty(businessUnitId) ? 'resourceType-${businessUnitId}-${nameConvSuffix}' : 'resourceType-${nameConvSuffix}' )

var nameConv_Mgmt_ResGroup = centralAVDManagement ? ( nameConvResTypeAtEnd ? 'avd-resGroupPurpose-${nameConvSuffix}' : 'resourceType-avd-resGroupPurpose-${nameConvSuffix}' ) : nameConv_Shared_ResGroups
var nameConv_Mgmt_Resources = centralAVDManagement ? ( nameConvResTypeAtEnd ? 'avd-${nameConvSuffix}' : 'resourceType-avd-${nameConvSuffix}' ) : nameConv_Shared_Resources

// Control Plane Resources
var resourceGroupControlPlane = replace(replace(replace(nameConv_Shared_ResGroups, 'resGroupPurpose', 'controlplane'), 'location', '${locations[locationControlPlane].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var workspaceName = replace(replace(nameConv_Mgmt_Resources, 'resourceType', resourceAbbreviations.workspaces), 'location', locations[locationControlPlane].abbreviation)
var desktopApplicationGroupName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.desktopApplicationGroups), 'location', locations[locationControlPlane].abbreviation)
var hostPoolName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.hostPools), 'location', locations[locationControlPlane].abbreviation)
var globalFeedResourceGroupName = replace(replace(replace(nameConv_Mgmt_ResGroup, 'resGroupPurpose', 'global-feed'), 'location', '${locations[locationVirtualMachines].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var globalFeedWorkspaceName = replace((nameConvResTypeAtEnd ? 'avd-feed-global-resourceType' : 'resourceType-avd-feed-global'), 'resourceType', resourceAbbreviations.workspaces)
// Compute Resources
var resourceGroupHosts = replace(replace(replace(nameConv_HP_ResGroups, 'resGroupPurpose', 'hosts'), 'location', '${locations[locationControlPlane].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var availabilitySetNamePrefix = '${replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.availabilitySets), 'location', locations[locationVirtualMachines].abbreviation)}-'
var diskNamePrefix = virtualMachineNamePrefix
var networkInterfaceNamePrefix = virtualMachineNamePrefix
// Management Resources
var resourceGroupManagement = replace(replace(replace(nameConv_Mgmt_ResGroup, 'resGroupPurpose', 'management'), 'location', '${locations[locationVirtualMachines].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var automationAccountName = replace(replace(nameConv_Mgmt_Resources, 'resourceType', resourceAbbreviations.automationAccounts), 'location', locations[locationVirtualMachines].abbreviation)
// the AVD Insights data collection rule must start with 'microsoft-avdi-'
var dataCollectionRulesName = 'microsoft-avdi-${replace(replace(replace(nameConv_Mgmt_Resources, 'resourceType', resourceAbbreviations.dataCollectionRules), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', '')}'
var diskEncryptionSetName = replace(replace(nameConv_Mgmt_Resources, 'resourceType', resourceAbbreviations.diskEncryptionSets), 'location', locations[locationVirtualMachines].abbreviation)
var keyVaultName = replace(replace(nameConv_Mgmt_Resources, 'resourceType', resourceAbbreviations.keyVaults), 'location', locations[locationVirtualMachines].abbreviation)
var KeyVaultUniqueString = take(uniqueString(keyVaultName,resourceGroupManagement, subscription().subscriptionId), 24 - (length(keyVaultName)+1))
var keyVaultUniqueName = nameConvResTypeAtEnd ? replace(keyVaultName, '-${resourceAbbreviations.keyVaults}', '-${KeyVaultUniqueString}-${resourceAbbreviations.keyVaults}') : '${keyVaultName}-${KeyVaultUniqueString}' 
var logAnalyticsWorkspaceName = replace(replace(nameConv_Mgmt_Resources, 'resourceType', resourceAbbreviations.logAnalyticsWorkspaces), 'location', locations[locationControlPlane].abbreviation)
var recoveryServicesVaultName = replace(replace(nameConv_Mgmt_Resources, 'resourceType', resourceAbbreviations.recoveryServicesVaults), 'location', locations[locationVirtualMachines].abbreviation)
var userAssignedIdentityNameConv = replace(replace(replace(nameConv_Mgmt_Resources, 'resourceType', resourceAbbreviations.userAssignedIdentities), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', 'avd-uaiPurpose-')

// Storage Resources
var resourceGroupStorage = replace(replace(replace(nameConv_HP_ResGroups, 'resGroupPurpose', 'storage'), 'location', '${locations[locationVirtualMachines].abbreviation}'), 'resourceType', '${resourceAbbreviations.resourceGroups}')
var netAppAccountName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.netAppAccounts), 'location', locations[locationVirtualMachines].abbreviation)
var netAppCapacityPoolName = replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.netAppCapacityPools), 'location', locations[locationVirtualMachines].abbreviation)
var storageAccountNamePrefix = empty(fslogixStorageCustomPrefix) ? toLower('${replace(replace(replace(replace(replace(nameConv_HP_Resources, 'resourceType', resourceAbbreviations.storageAccounts), hostPoolBaseName, '${hostPoolBaseName}fsl'), 'location', locations[locationVirtualMachines].abbreviation), 'avd-', ''), '-', '')}') : fslogixStorageCustomPrefix
var privateEndpointNameConv = replace('${nameConvResTypeAtEnd ? 'resource-subresource-resourceType' : 'resourceType-resource-subresource'}', 'resourceType', resourceAbbreviations.privateEndpoints)

output availabilitySetNamePrefix string = availabilitySetNamePrefix
output automationAccountName string = automationAccountName
output dataCollectionRulesName string = dataCollectionRulesName
output desktopApplicationGroupName string = desktopApplicationGroupName
output diskEncryptionSetName string = diskEncryptionSetName
output diskNamePrefix string = diskNamePrefix
output globalFeedWorkspaceName string = globalFeedWorkspaceName
output fileShareNames object = fileShareNames
output hostPoolName string = hostPoolName
output keyVaultName string = keyVaultUniqueName
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
output resourceGroupStorage string = resourceGroupStorage
output storageAccountNamePrefix string = storageAccountNamePrefix
output userAssignedIdentityNameConv string = userAssignedIdentityNameConv
output workspaceName string = workspaceName
