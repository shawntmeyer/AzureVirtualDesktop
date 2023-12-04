targetScope = 'subscription'

param Environment string
param BusinessUnitIdentifier string
param CentralizedAVDManagement bool
param FslogixStorageCustomPrefix string
param HostpoolIdentifier string
param LocationControlPlane string
param LocationVirtualMachines string
param NameConvResTypeAtEnd bool
param VirtualMachineNamePrefix string

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
// automatically add 'avd-' prefix to the prefix if it isn't already listed.
var BusinessUnitFinal = contains(BusinessUnitIdentifier, 'avd') ? BusinessUnitIdentifier : 'avd-${BusinessUnitIdentifier}'
var HostpoolFinal = !empty(BusinessUnitIdentifier) ? HostpoolIdentifier : ( contains(HostpoolIdentifier, 'avd') ? HostpoolIdentifier : 'avd-${HostpoolIdentifier}' )

var NameConv_Prefix_withoutResType = !empty(BusinessUnitIdentifier) ? '${BusinessUnitFinal}-${HostpoolFinal}' : HostpoolFinal
var NameConvPrefix = NameConvResTypeAtEnd ? NameConv_Prefix_withoutResType : 'resourceType-${NameConv_Prefix_withoutResType}' 

var NameConv_Suffix_withoutResType = !empty(Environment) ? '${Environment}-location' : 'location'
var NameConvSuffix = NameConvResTypeAtEnd ? '${NameConv_Suffix_withoutResType}-resourceType' : NameConv_Suffix_withoutResType

var NameConv_ResGroups = '${NameConvPrefix}-resGroupPurpose-${NameConvSuffix}'
var NameConv_Resources = '${NameConvPrefix}-${NameConvSuffix}'

var NameConv_Shared_ResGroups = NameConvResTypeAtEnd ? ( !empty(BusinessUnitIdentifier) ? '${BusinessUnitFinal}-resGroupPurpose-${NameConvSuffix}' : 'resGroupPurpose-${NameConvSuffix}' ) : ( !empty(BusinessUnitIdentifier) ? 'resourceType-${BusinessUnitFinal}-resGroupPurpose-${NameConvSuffix}' : 'resourceType-resGroupPurpose-${NameConvSuffix}' )
var NameConv_Shared_Resources = NameConvResTypeAtEnd ? ( !empty(BusinessUnitIdentifier) ? '${BusinessUnitFinal}-${NameConvSuffix}' : '${NameConvSuffix}' ) : (!empty(BusinessUnitFinal) ? 'resourceType-${BusinessUnitFinal}-${NameConvSuffix}' : 'resourceType-${NameConvSuffix}' )

var NameConv_Mgmt_ResGroup = CentralAVDManagement ? ( NameConvResTypeAtEnd ? 'avd-resGroupPurpose-${NameConvSuffix}' : 'resourceType-avd-resGroupPurpose-${NameConvSuffix}' ) : NameConv_Shared_ResGroups
var NameConv_Mgmt_Resources = CentralAVDManagement ? ( NameConvResTypeAtEnd ? 'avd-${NameConvSuffix}' : 'resourceType-avd-${NameConvSuffix}' ) : NameConv_Shared_Resources

// Control Plane Resources
var ResourceGroupControlPlane = replace(replace(replace(NameConv_Shared_ResGroups, 'resGroupPurpose', 'controlplane'), 'location', '${Locations[LocationControlPlane].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var DesktopApplicationGroupName = replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.desktopApplicationGroups), 'location', Locations[LocationControlPlane].abbreviation)
var HostPoolName = replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.hostPools), 'location', Locations[LocationControlPlane].abbreviation)
// Compute Resources
var ResourceGroupHosts = replace(replace(replace(NameConv_ResGroups, 'resGroupPurpose', 'hosts'), 'location', '${Locations[LocationControlPlane].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var AvailabilitySetNamePrefix = '${replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.availabilitySets), 'location', Locations[LocationVirtualMachines].abbreviation)}-'
var DiskNamePrefix = VirtualMachineNamePrefix
var NetworkInterfaceNamePrefix = VirtualMachineNamePrefix
// Management Resources
var ResourceGroupManagement = replace(replace(replace(NameConv_Mgmt_ResGroup, 'resGroupPurpose', 'management'), 'location', '${Locations[LocationVirtualMachines].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var AutomationAccountName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.automationAccounts), 'location', Locations[LocationVirtualMachines].abbreviation)
// the AVD Insights data collection rule must start with 'microsoft-avdi-'
var DataCollectionRulesName = 'microsoft-avdi-${replace(replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.dataCollectionRules), 'location', Locations[LocationVirtualMachines].abbreviation), 'avd-', '')}'
var DiskEncryptionSetName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.diskEncryptionSets), 'location', Locations[LocationVirtualMachines].abbreviation)
var KeyVaultName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.keyVaults), 'location', Locations[LocationVirtualMachines].abbreviation)
var LogAnalyticsWorkspaceName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.logAnalyticsWorkspaces), 'location', Locations[LocationControlPlane].abbreviation)
var RecoveryServicesVaultName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.recoveryServicesVaults), 'location', Locations[LocationVirtualMachines].abbreviation)
var UserAssignedIdentityName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.userAssignedIdentities), 'location', Locations[LocationVirtualMachines].abbreviation)
var WorkspaceName = replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.workspaces), 'location', Locations[LocationControlPlane].abbreviation)
// Storage Resources
var ResourceGroupStorage = replace(replace(replace(NameConv_ResGroups, 'resGroupPurpose', 'storage'), 'location', '${Locations[LocationVirtualMachines].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var NetAppAccountName = replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.netAppAccounts), 'location', Locations[LocationVirtualMachines].abbreviation)
var NetAppCapacityPoolName = replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.netAppCapacityPools), 'location', Locations[LocationVirtualMachines].abbreviation)
var StorageAccountNamePrefix = empty(FslogixStorageCustomPrefix) ? toLower('fsl${replace(replace(replace(replace(NameConv_Resources, 'resourceType', ''), 'location', Locations[LocationVirtualMachines].abbreviation), 'avd-', ''), '-', '')}') : FslogixStorageCustomPrefix

output AvailabilitySetNamePrefix string = AvailabilitySetNamePrefix
output AutomationAccountName string = AutomationAccountName
output DataCollectionRulesName string = DataCollectionRulesName
output DesktopApplicationGroupName string = DesktopApplicationGroupName
output DiskEncryptionSetName string = DiskEncryptionSetName
output DiskNamePrefix string = DiskNamePrefix
output FileShareNames object = FileShareNames
output HostPoolName string = HostPoolName
output KeyVaultName string = KeyVaultName
output Locations object = Locations
output LogAnalyticsWorkspaceName string = LogAnalyticsWorkspaceName
output NetAppAccountName string = NetAppAccountName
output NetAppCapacityPoolName string = NetAppCapacityPoolName
output NetworkInterfaceNamePrefix string = NetworkInterfaceNamePrefix
output RecoveryServicesVaultName string = RecoveryServicesVaultName
output ResourceGroupControlPlane string = ResourceGroupControlPlane
output ResourceGroupHosts string = ResourceGroupHosts
output ResourceGroupManagement string = ResourceGroupManagement
output ResourceGroupStorage string = ResourceGroupStorage
output StorageAccountNamePrefix string = StorageAccountNamePrefix
output UserAssignedIdentityName string = UserAssignedIdentityName
output WorkspaceName string = WorkspaceName
