targetScope = 'subscription'

param Environment string
param BusinessUnitIdentifier string
param CentralizedAVDManagement bool
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

var NameConv_Prefix_init = !empty(BusinessUnitIdentifier) ? '${BusinessUnitIdentifier}-${HostpoolIdentifier}' : HostpoolIdentifier
var NameConv_Prefix = NameConvResTypeAtEnd ? NameConv_Prefix_init : 'resourceType-${NameConv_Prefix_init}' 

var NameConv_Suffix_init = !empty(Environment) ? '${Environment}-location' : 'location'
var NameConv_Suffix = NameConvResTypeAtEnd ? '${NameConv_Suffix_init}-resourceType' : NameConv_Suffix_init

var NameConv_Resources = '${NameConv_Prefix}-${NameConv_Suffix}'
var NameConv_ResGroups = '${NameConv_Prefix}-purpose-${NameConv_Suffix}'
var NameConv_Shared_Resources = !empty(BusinessUnitIdentifier) ? '${BusinessUnitIdentifier}-${NameConv_Suffix}' : '${NameConv_Suffix}'
var NameConv_Shared_ResGroups = !empty(BusinessUnitIdentifier) ? '${BusinessUnitIdentifier}-purpose-${NameConv_Suffix}' : 'purpose-${NameConv_Suffix}'
var NameConv_Mgmt_Resources = !CentralAVDManagement ? NameConv_Shared_Resources : '${NameConv_Suffix}'
var NameConv_Mgmt_ResGroup = !CentralAVDManagement ? NameConv_Shared_ResGroups : 'purpose-${NameConv_Suffix}'

var ResourceGroupControlPlane = replace(replace(replace(NameConv_Shared_ResGroups, 'purpose', 'avd-controlplane'), 'location', '${Locations[LocationControlPlane].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var ResourceGroupHosts = replace(replace(replace(NameConv_ResGroups, 'purpose', 'avd-hosts'), 'location', '${Locations[LocationControlPlane].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var ResourceGroupManagement = replace(replace(replace(NameConv_Mgmt_ResGroup, 'purpose', 'avd-management'), 'location', '${Locations[LocationVirtualMachines].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')
var ResourceGroupStorage = replace(replace(replace(NameConv_ResGroups, 'purpose', 'avd-storage'), 'location', '${Locations[LocationVirtualMachines].abbreviation}'), 'resourceType', '${ResourceAbbreviations.resourceGroups}')

var AvailabilitySetNamePrefix = '${replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.availabilitySets), 'location', Locations[LocationVirtualMachines].abbreviation)}-'
var AutomationAccountName = 'avd-${replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.automationAccounts), 'location', Locations[LocationVirtualMachines].abbreviation)}'
// the AVD Insights data collection rule must start with 'microsoft-avdi-'
var DataCollectionRulesName = 'microsoft-avdi-${replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.dataCollectionRules), 'location', Locations[LocationVirtualMachines].abbreviation)}'
var DesktopApplicationGroupName = replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.desktopApplicationGroups), 'location', Locations[LocationControlPlane].abbreviation)
var DiskEncryptionSetName = 'avd-${replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.diskEncryptionSets), 'location', Locations[LocationVirtualMachines].abbreviation)}'
var DiskNamePrefix = VirtualMachineNamePrefix
var HostPoolName = replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.hostPools), 'location', Locations[LocationControlPlane].abbreviation)
var KeyVaultName = 'avd-${replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.keyVaults), 'location', Locations[LocationVirtualMachines].abbreviation)}'
var LogAnalyticsWorkspaceName = 'avd-${replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.logAnalyticsWorkspaces), 'location', Locations[LocationControlPlane].abbreviation)}'
var NetAppAccountName = replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.netAppAccounts), 'location', Locations[LocationVirtualMachines].abbreviation)
var NetAppCapacityPoolName = replace(replace(NameConv_Resources, 'resourceType', ResourceAbbreviations.netAppCapacityPools), 'location', Locations[LocationVirtualMachines].abbreviation)
var NetworkInterfaceNamePrefix = VirtualMachineNamePrefix
var RecoveryServicesVaultName = 'avd-${replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.recoveryServicesVaults), 'location', Locations[LocationVirtualMachines].abbreviation)}'
var StorageAccountNamePrefix = toLower('fsl${replace(replace(replace(NameConv_Resources, 'resourceType', ''), 'location', Locations[LocationVirtualMachines].abbreviation), '-', '')}')
var UserAssignedIdentityName = 'avd-${replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.userAssignedIdentities), 'location', Locations[LocationVirtualMachines].abbreviation)}'
var WorkspaceName = 'avd-${replace(replace(NameConv_Mgmt_Resources, 'resourceType', ResourceAbbreviations.workspaces), 'location', Locations[LocationControlPlane].abbreviation)}'

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
