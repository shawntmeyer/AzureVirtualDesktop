targetScope = 'subscription'

param Environment string
param AVDWorkspaceIdentifier string
param AVDHostpoolIdentifier string
param LocationControlPlane string
param LocationVirtualMachines string

var AvailabilitySetNamePrefix = '${replace(replace(NamingConvention, 'resourceType', ResourceAbbreviations.availabilitySets), 'location', Locations[LocationVirtualMachines].abbreviation)}-'
var AutomationAccountName = replace(replace(NamingConvention_SharedServices, 'resourceType', ResourceAbbreviations.automationAccounts), 'location', Locations[LocationVirtualMachines].abbreviation)
var DesktopApplicationGroupName = replace(replace(NamingConvention, 'resourceType', ResourceAbbreviations.desktopApplicationGroups), 'location', Locations[LocationControlPlane].abbreviation)
var DiskEncryptionSetName = replace(replace(NamingConvention_SharedServices, 'resourceType', ResourceAbbreviations.diskEncryptionSets), 'location', Locations[LocationVirtualMachines].abbreviation)
var DiskNamePrefix = '${replace(replace(NamingConvention, 'resourceType', ResourceAbbreviations.disks), 'location', Locations[LocationVirtualMachines].abbreviation)}-'
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
var HostPoolName = replace(replace(NamingConvention, 'resourceType', ResourceAbbreviations.hostPools), 'location', Locations[LocationControlPlane].abbreviation)
var KeyVaultName = replace(replace(NamingConvention_SharedServices, 'resourceType', ResourceAbbreviations.keyVaults), 'location', Locations[LocationVirtualMachines].abbreviation)
var Locations = loadJsonContent('../data/locations.json')
var LogAnalyticsWorkspaceName = replace(replace(NamingConvention_SharedServices, 'resourceType', ResourceAbbreviations.logAnalyticsWorkspaces), 'location', Locations[LocationControlPlane].abbreviation)
var NamingConvention = !empty(Environment) ? '${AVDWorkspaceIdentifier}-${AVDHostpoolIdentifier}-${Environment}-location-resourceType' : '${AVDWorkspaceIdentifier}-${AVDHostpoolIdentifier}-location-resourceType'
var NamingConvention_SharedServices = !empty(Environment) ? '${AVDWorkspaceIdentifier}-${Environment}-location-resourceType' : '${AVDWorkspaceIdentifier}-location-resourceType'
var NetAppAccountName = replace(replace(NamingConvention, 'resourceType', ResourceAbbreviations.netAppAccounts), 'location', Locations[LocationVirtualMachines].abbreviation)
var NetAppCapacityPoolName = replace(replace(NamingConvention, 'resourceType', ResourceAbbreviations.netAppCapacityPools), 'location', Locations[LocationVirtualMachines].abbreviation)
var NetworkInterfaceNamePrefix = '${replace(replace(NamingConvention, 'resourceType', ResourceAbbreviations.networkInterfaces), 'location', Locations[LocationVirtualMachines].abbreviation)}-'
var RecoveryServicesVaultName = replace(replace(NamingConvention_SharedServices, 'resourceType', ResourceAbbreviations.recoveryServicesVaults), 'location', Locations[LocationVirtualMachines].abbreviation)
var ResourceAbbreviations = loadJsonContent('../data/resourceAbbreviations.json')

var ResourceGroupControlPlane = replace(replace(NamingConvention, 'resourceType', 'vd-controlPlane-${ResourceAbbreviations.resourceGroups}'), 'location', Locations[LocationControlPlane].abbreviation)
var ResourceGroupHosts = replace(replace(NamingConvention, 'resourceType', 'vd-hosts-${ResourceAbbreviations.resourceGroups}'), 'location', Locations[LocationVirtualMachines].abbreviation)
var ResourceGroupManagement = replace(replace(NamingConvention_SharedServices, 'resourceType', 'vd-management-${ResourceAbbreviations.resourceGroups}'), 'location', Locations[LocationVirtualMachines].abbreviation)
var ResourceGroupStorage = replace(replace(NamingConvention, 'resourceType', 'vd-storage-${ResourceAbbreviations.resourceGroups}'), 'location', Locations[LocationVirtualMachines].abbreviation)
var StorageAccountNamePrefix = replace(replace(replace(NamingConvention, 'resourceType', ResourceAbbreviations.storageAccounts), 'location', Locations[LocationVirtualMachines].abbreviation), '-', '')
var UserAssignedIdentityName = replace(replace(NamingConvention_SharedServices, 'resourceType', ResourceAbbreviations.userAssignedIdentities), 'location', Locations[LocationVirtualMachines].abbreviation)
var WorkspaceName = replace(replace(NamingConvention_SharedServices, 'resourceType', ResourceAbbreviations.workspaces), 'location', Locations[LocationControlPlane].abbreviation)

output AvailabilitySetNamePrefix string = AvailabilitySetNamePrefix
output AutomationAccountName string = AutomationAccountName
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
