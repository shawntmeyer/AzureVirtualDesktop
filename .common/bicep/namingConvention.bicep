targetScope = 'subscription'

param ArtifactsStorageAccountCustomName string = ''
param Environment string = ''
param BusinessUnitIdentifier string = ''
param CentralizedAVDManagement bool
param FslogixStorageCustomPrefix string = ''
param HostpoolIdentifier string = ''
param LocationManagement string = ''
param LocationVirtualMachines string = ''
param ManagedIdentityCustomName string = ''
param NameConvResTypeAtEnd bool
param VirtualMachineNamePrefix string = ''
param ComputeGalleryCustomName string = ''

// Ensure that Centralized AVD Managment resource group and resources are created appropriately
var CentralAVDManagement = !empty(BusinessUnitIdentifier) ? CentralizedAVDManagement : true

var FileShareNames = {
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

var Locations = loadJsonContent('../data/locations.json')
var ResourceAbbreviations = loadJsonContent('../data/resourceAbbreviations.json')

// automatically add '-avd' to the Business Unit Identifier for the prefix if needed.
var BusinessUnitId = !empty(BusinessUnitIdentifier) ? (contains(BusinessUnitIdentifier, 'avd') ? BusinessUnitIdentifier : '${BusinessUnitIdentifier}-avd') : ''
// automaticall add 'avd-' to the Hostpool Identifier for the prefix if needed.
var HostpoolId = !empty(BusinessUnitIdentifier) ? HostpoolIdentifier : ( contains(HostpoolIdentifier, 'avd') ? HostpoolIdentifier : 'avd-${HostpoolIdentifier}' )
// Calculate Hostpool Name Prefix
var HostpoolBaseName = !empty(BusinessUnitIdentifier) ? '${BusinessUnitId}-${HostpoolId}' : HostpoolId
var HostPoolPrefix = NameConvResTypeAtEnd ? HostpoolBaseName : 'resourceType-${HostpoolBaseName}' 
// Calculate Naming Convention Suffix
var NameConv_Suffix_withoutResType = !empty(Environment) ? '${Environment}-location' : 'location'
var NameConvSuffix = NameConvResTypeAtEnd ? '${NameConv_Suffix_withoutResType}-resourceType' : NameConv_Suffix_withoutResType
// Calculate Hostpool Specific Item Naming Convention
var NameConv_HostpoolResGroups = '${HostPoolPrefix}-resGroupPurpose-${NameConvSuffix}'
var NameConv_HostpoolResources = '${HostPoolPrefix}-${NameConvSuffix}'
// Shared Management Items when AVD Management is not centralized 
var NameConv_Shared_ResGroups = NameConvResTypeAtEnd ? ( !empty(BusinessUnitIdentifier) ? '${BusinessUnitId}-resGroupPurpose-${NameConvSuffix}' : 'resGroupPurpose-${NameConvSuffix}' ) : ( !empty(BusinessUnitIdentifier) ? 'resourceType-${BusinessUnitId}-resGroupPurpose-${NameConvSuffix}' : 'resourceType-resGroupPurpose-${NameConvSuffix}' )
var NameConv_Shared_Resources = NameConvResTypeAtEnd ? ( !empty(BusinessUnitIdentifier) ? '${BusinessUnitId}-${NameConvSuffix}' : '${NameConvSuffix}' ) : (!empty(BusinessUnitId) ? 'resourceType-${BusinessUnitId}-${NameConvSuffix}' : 'resourceType-${NameConvSuffix}' )
// Build Naming Convention for Management Items
var NameConv_Mgmt_ResGroups = CentralAVDManagement ? ( NameConvResTypeAtEnd ? 'avd-resGroupPurpose-${NameConvSuffix}' : 'resourceType-avd-resGroupPurpose-${NameConvSuffix}' ) : NameConv_Shared_ResGroups
var NameConv_Mgmt_Resources = CentralAVDManagement ? ( NameConvResTypeAtEnd ? 'avd-${NameConvSuffix}' : 'resourceType-avd-${NameConvSuffix}' ) : NameConv_Shared_Resources
// AVD Control Plane Resources
var DesktopApplicationGroupName = replace(replace(NameConv_HostpoolResources, 'resourceType', ResourceAbbreviations.desktopApplicationGroups), 'location', Locations[LocationManagement].abbreviation)
var HostPoolName = replace(replace(NameConv_HostpoolResources, 'resourceType', ResourceAbbreviations.hostPools), 'location', Locations[LocationManagement].abbreviation)
// AVD Compute Resources
var ResourceGroupHosts = replace(replace(replace(NameConv_HostpoolResGroups, 'resGroupPurpose', 'hosts'), 'location', '${Locations[LocationManagement].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var AvailabilitySetNamePrefix = '${replace(replace(NameConv_HostpoolResources, 'resourceType', ResourceAbbreviations.availabilitySets), 'location', Locations[LocationVirtualMachines].abbreviation)}-'
var DiskNamePrefix = VirtualMachineNamePrefix
var NetworkInterfaceNamePrefix = VirtualMachineNamePrefix
// AVD Management Resources
var ResourceGroupManagement = replace(replace(replace(NameConv_Mgmt_ResGroups, 'resGroupPurpose', 'management'), 'location', '${Locations[LocationManagement].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var AutomationAccountName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.automationAccounts), 'location', Locations[LocationManagement].abbreviation)
// the AVD Insights data collection rule must start with 'microsoft-avdi-'
var DataCollectionRulesName = 'microsoft-avdi-${replace(replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.dataCollectionRules), 'location', Locations[LocationManagement].abbreviation), 'avd-', '')}'
var DiskEncryptionSetName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.diskEncryptionSets), 'location', Locations[LocationManagement].abbreviation)
var KeyVaultName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.keyVaults), 'location', Locations[LocationManagement].abbreviation)
var LogAnalyticsWorkspaceName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.logAnalyticsWorkspaces), 'location', Locations[LocationManagement].abbreviation)
var RecoveryServicesVaultName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.recoveryServicesVaults), 'location', Locations[LocationManagement].abbreviation)
var UserAssignedIdentityName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.userAssignedIdentities), 'location', Locations[LocationManagement].abbreviation)
var WorkspaceName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.workspaces), 'location', Locations[LocationManagement].abbreviation)
// Profile Storage Resources
var ResourceGroupStorage = replace(replace(replace(NameConv_HostpoolResGroups, 'resGroupPurpose', 'storage'), 'location', '${Locations[LocationVirtualMachines].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var NetAppAccountName = replace(replace(NameConv_HostpoolResources, 'resourceType', ResourceAbbreviations.netAppAccounts), 'location', Locations[LocationVirtualMachines].abbreviation)
var NetAppCapacityPoolName = replace(replace(NameConv_HostpoolResources, 'resourceType', ResourceAbbreviations.netAppCapacityPools), 'location', Locations[LocationVirtualMachines].abbreviation)
var StorageAccountNamePrefix = empty(FslogixStorageCustomPrefix) ? toLower('${replace(replace(replace(replace(replace(NameConv_HostpoolResources, 'resourceType', ResourceAbbreviations.storageAccounts), HostpoolBaseName, '${HostpoolBaseName}fsl'),  'location', Locations[LocationVirtualMachines].abbreviation), 'avd-', ''), '-', '')}') : FslogixStorageCustomPrefix

// Image Management Resources
var ResourceGroupImageManagement = replace(replace(replace(NameConv_Mgmt_ResGroups, 'resGroupPurpose', 'image-management'), 'location', '${Locations[LocationManagement].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var ArtifactsStorageAccountName = !empty(ArtifactsStorageAccountCustomName) ? ArtifactsStorageAccountCustomName : toLower('${replace(replace(replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.storageAccounts), 'location', Locations[LocationManagement].abbreviation), 'avd-', 'avdimgmgmt'), '-', '')}')  // the storage account name must be lowercase and cannot contain hyphens
var ComputeGalleryName = !empty(ComputeGalleryCustomName) ? ComputeGalleryCustomName : replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.computeGalleries), 'location', Locations[LocationManagement].abbreviation)
var ManagedIdentityName = !empty(ManagedIdentityCustomName) ? ManagedIdentityCustomName : replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.userAssignedIdentities), 'location', Locations[LocationManagement].abbreviation)

var PrivateEndpointNameConv = replace('${NameConvResTypeAtEnd ? 'resource-subresource-resourceType' : 'resourceType-resource-subresource'}', 'resourceType', ResourceAbbreviations.privateEndpoints)

output ArtifactsStorageAccountName string = ArtifactsStorageAccountName
output AvailabilitySetNamePrefix string = AvailabilitySetNamePrefix
output AutomationAccountName string = AutomationAccountName
output DataCollectionRulesName string = DataCollectionRulesName
output DesktopApplicationGroupName string = DesktopApplicationGroupName
output DiskEncryptionSetName string = DiskEncryptionSetName
output DiskNamePrefix string = DiskNamePrefix
output FileShareNames object = FileShareNames
output HostPoolName string = HostPoolName
output ComputeGalleryName string = ComputeGalleryName
output KeyVaultName string = KeyVaultName
output Locations object = Locations
output LogAnalyticsWorkspaceName string = LogAnalyticsWorkspaceName
output ManagedIdentityName string = ManagedIdentityName
output NetAppAccountName string = NetAppAccountName
output NetAppCapacityPoolName string = NetAppCapacityPoolName
output NetworkInterfaceNamePrefix string = NetworkInterfaceNamePrefix
output PrivateEndpointNameConv string = PrivateEndpointNameConv
output RecoveryServicesVaultName string = RecoveryServicesVaultName
output ResourceGroupHosts string = ResourceGroupHosts
output ResourceGroupImageManagement string = ResourceGroupImageManagement
output ResourceGroupManagement string = ResourceGroupManagement
output ResourceGroupStorage string = ResourceGroupStorage
output StorageAccountNamePrefix string = StorageAccountNamePrefix
output UserAssignedIdentityName string = UserAssignedIdentityName
output WorkspaceName string = WorkspaceName
