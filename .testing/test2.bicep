targetScope = 'subscription'
var locationVirtualMachines = 'usseceast'
var locationControlPlane = 'ussecwest'
var identifier = 'myavd'
var index = ''
var nameConvResTypeAtEnd = false


var cloud = 'ussec'
var locations = startsWith(cloud, 'us') ? (loadJsonContent('../.common/data/locations.json')).other : (loadJsonContent('../.common/data/locations.json'))[environment().name]
#disable-next-line BCP329
var varLocationVirtualMachines = startsWith(cloud, 'us') ? substring(locationVirtualMachines, 5, length(locationVirtualMachines)-5) : locationVirtualMachines
#disable-next-line BCP329
var locationVirtualMachinesAbbreviation = locations[varLocationVirtualMachines].abbreviation
#disable-next-line BCP329
var varLocationControlPlane = startsWith(cloud, 'us') ? substring(locationControlPlane, 5, length(locationControlPlane)-5) : locationControlPlane
var locationControlPlaneAbbreviation = locations[varLocationControlPlane].abbreviation

var resourceAbbreviations = loadJsonContent('../.common/data/resourceAbbreviations.json')

var nameConvReversed = nameConvResTypeAtEnd

var hpIdentifier = identifier
var hpIndex = index  

var hpBaseName = empty(hpIndex) ? hpIdentifier : '${hpIdentifier}-${hpIndex}'
var hpResPrfx = nameConvReversed ? hpBaseName : 'RESOURCETYPE-${hpBaseName}'

var nameConvSuffix = nameConvReversed ? 'LOCATION-RESOURCETYPE' : 'LOCATION'

// Management, Monitoring, and Control Plane Resource Naming Conventions
var nameConv_Shared_ResGroup = nameConvReversed
  ? 'avd-TOKEN-${nameConvSuffix}'
  : 'RESOURCETYPE-avd-TOKEN-${nameConvSuffix}'
var nameConv_Shared_Resources = nameConvReversed
  ? 'avd-TOKEN-${nameConvSuffix}'
  : 'RESOURCETYPE-avd-TOKEN-${nameConvSuffix}'

// HostPool Specific Resource Naming Conventions
var nameConv_HP_ResGroups = nameConvReversed
  ? 'avd-${hpBaseName}-TOKEN-${nameConvSuffix}'
  : 'RESOURCETYPE-avd-${hpBaseName}-TOKEN-${nameConvSuffix}'
var nameConv_HP_Resources = '${hpResPrfx}-TOKEN-${nameConvSuffix}'

// Deployment Resources (temporary resource group for deployment purposes)
var resourceGroupDeployment = replace(
  replace(
    replace(nameConv_HP_ResGroups, 'TOKEN', 'deployment'),
    'LOCATION',
    '${locationVirtualMachinesAbbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
)
var depVirtualMachineNameTemp = replace(
  replace(
    replace(
      replace(nameConv_HP_Resources, 'RESOURCETYPE', ''),
      'LOCATION',
      locationVirtualMachinesAbbreviation
    ),
    'TOKEN-',
    ''
  ),
  '-',
  ''
)
var depVirtualMachineName = take('${depVirtualMachineNameTemp}${uniqueString(depVirtualMachineNameTemp)}', 15)
var depVirtualMachineDiskName = '${depVirtualMachineName}-${resourceAbbreviations.osdisks}'
var depVirtualMachineNicName = '${depVirtualMachineName}-${resourceAbbreviations.networkInterfaces}'

// Management and Monitoring Resource Names
var resourceGroupManagement = replace(
  replace(
    replace(nameConv_Shared_ResGroup, 'TOKEN', 'management'),
    'LOCATION',
    locationVirtualMachinesAbbreviation
  ),
  'RESOURCETYPE',
  resourceAbbreviations.resourceGroups
)
var uniqueStringManagement = take(uniqueString(subscription().subscriptionId, resourceGroupManagement), 6)
var appServicePlanName = replace(
  replace(
    replace(nameConv_Shared_Resources, 'RESOURCETYPE', resourceAbbreviations.appServicePlans),
    'LOCATION',
    locationVirtualMachinesAbbreviation
  ),
  'TOKEN-',
  ''
)

// key vaults must be named with a length of 3 - 24 characters and must be globally unique.
var keyVaultNameSecrets = replace(
  replace(
    replace(nameConv_Shared_Resources, 'TOKEN', 'sec-${uniqueStringManagement}'),
    'LOCATION',
    locationVirtualMachinesAbbreviation
  ),
  'RESOURCETYPE',
  resourceAbbreviations.keyVaults
)
var keyVaultNameEncryption = replace(
  replace(
    replace(nameConv_Shared_Resources, 'TOKEN', 'enc-${uniqueStringManagement}'),
    'LOCATION',
    locationVirtualMachinesAbbreviation
  ),
  'RESOURCETYPE',
  resourceAbbreviations.keyVaults
)

var dataCollectionEndpointName = replace(
  replace(
    replace(nameConv_Shared_Resources, 'RESOURCETYPE', resourceAbbreviations.dataCollectionEndpoints),
    'LOCATION',
    locationVirtualMachinesAbbreviation
  ),
  'TOKEN-',
  ''
)

var logAnalyticsWorkspaceName = replace(
  replace(
    replace(nameConv_Shared_Resources, 'RESOURCETYPE', resourceAbbreviations.logAnalyticsWorkspaces),
    'LOCATION',
    locationVirtualMachinesAbbreviation
  ),
  'TOKEN-',
  ''
)

// Control Plane HostPool Resources
var desktopApplicationGroupName = replace(
  replace(replace(nameConv_HP_Resources, 'TOKEN-', ''), 'RESOURCETYPE', resourceAbbreviations.desktopApplicationGroups),
  'LOCATION',
  locationControlPlaneAbbreviation
)
var hostPoolName = replace(
  replace(replace(nameConv_HP_Resources, 'TOKEN-', ''), 'RESOURCETYPE', resourceAbbreviations.hostPools),
  'LOCATION',
  locationControlPlaneAbbreviation
)
var scalingPlanName = replace(
  replace(replace(nameConv_HP_Resources, 'TOKEN-', ''), 'RESOURCETYPE', resourceAbbreviations.scalingPlans),
  'LOCATION',
  locationControlPlaneAbbreviation
)

// Common HostPool Specific Resource Naming Conventions
var uniqueStringHosts = take(uniqueString(subscription().subscriptionId, resourceGroupHosts), 6)
var appInsightsNameConv = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.applicationInsights),
  'LOCATION',
  locationVirtualMachinesAbbreviation
)
var functionAppNameConv = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.functionApps),
  'LOCATION',
  locationVirtualMachinesAbbreviation
)

var privateEndpointNameConv = replace(
  nameConvReversed ? 'RESOURCE-SUBRESOURCE-VNETID-RESOURCETYPE' : 'RESOURCETYPE-RESOURCE-SUBRESOURCE-VNETID',
  'RESOURCETYPE',
  resourceAbbreviations.privateEndpoints
)
var privateEndpointNICNameConvTemp = nameConvReversed
  ? '${privateEndpointNameConv}-RESOURCETYPE'
  : 'RESOURCETYPE-${privateEndpointNameConv}'
var privateEndpointNICNameConv = replace(
  privateEndpointNICNameConvTemp,
  'RESOURCETYPE',
  resourceAbbreviations.networkInterfaces
)
var recoveryServicesVaultsNameConv = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.recoveryServicesVaults),
  'LOCATION',
  locationVirtualMachinesAbbreviation
)
var userAssignedIdentityNameConv = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.userAssignedIdentities),
  'LOCATION',
  locationVirtualMachinesAbbreviation
)

// Compute Resources
var resourceGroupHosts = replace(
  replace(
    replace(nameConv_HP_ResGroups, 'TOKEN', 'hosts'),
    'LOCATION',
    '${locationVirtualMachinesAbbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
)

var diskAccessName = replace(
  replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.diskAccesses),
    'LOCATION',
    locationVirtualMachinesAbbreviation
  ),
  'TOKEN-',
  ''
)
// Disk Encryption Set Names - Max length 80 Characters
var diskEncryptionSetNameConv = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.diskEncryptionSets),
  'LOCATION',
  locationVirtualMachinesAbbreviation
)

// Storage Resources
var resourceGroupStorage = replace(
  replace(
    replace(nameConv_HP_ResGroups, 'TOKEN', 'storage'),
    'LOCATION',
    '${locationVirtualMachinesAbbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
)
var netAppAccountName = replace(
  replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.netAppAccounts),
    'LOCATION',
    locationVirtualMachinesAbbreviation
  ),
  'TOKEN-',
  ''
)
var netAppCapacityPoolName = replace(
  replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.netAppCapacityPools),
    'LOCATION',
    locationVirtualMachinesAbbreviation
  ),
  'TOKEN-',
  ''
)

// App Attach and FSLogix Storage Account Naming Convention (max 15 characters for domain join)
var appAttachStorageAccountName = take('appattach${uniqueStringManagement}', 15)
var uniqueStringStorage = take(uniqueString(subscription().subscriptionId, resourceGroupStorage), 6)
var increaseQuotaFAStorageAccountName = 'saquota${uniqueStringStorage}'
var sessionHostReplacerFAStorageAccountName = 'shreplacer${uniqueStringHosts}'

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

output appInsightsNames object = {
  increaseStorageQuota: replace(appInsightsNameConv, 'TOKEN-', 'saquota-${uniqueStringStorage}-')
  sessionHostReplacement: replace(appInsightsNameConv, 'TOKEN-', 'shreplacer-${uniqueStringHosts}-')
}
output appServicePlanName string = appServicePlanName
output dataCollectionEndpointName string = dataCollectionEndpointName
output depVirtualMachineName string = depVirtualMachineName
output depVirtualMachineNicName string = depVirtualMachineNicName
output depVirtualMachineDiskName string = depVirtualMachineDiskName
output desktopApplicationGroupName string = desktopApplicationGroupName
output diskAccessName string = diskAccessName
output diskEncryptionSetNames object = {
  confidentialVMs: replace(diskEncryptionSetNameConv, 'TOKEN-', 'confvm-customer-keys-')
  customerManaged: replace(diskEncryptionSetNameConv, 'TOKEN-', 'customer-keys-')
  platformAndCustomerManaged: replace(diskEncryptionSetNameConv, 'TOKEN-', 'platform-and-customer-keys-')
}
output fslogixFileShareNames object = fslogixfileShareNames
output functionAppNames object = {
  increaseStorageQuota: replace(functionAppNameConv, 'TOKEN-', 'saquota-${uniqueStringStorage}-')
  sessionHostReplacement: replace(functionAppNameConv, 'TOKEN-', 'shreplacer-${uniqueStringHosts}-')
}

output hostPoolName string = hostPoolName
output keyVaultNames object = {
  encryptionKeys: keyVaultNameEncryption
  secrets: keyVaultNameSecrets
}
output encryptionKeyNames object = {
  appAttach: 'encryption-key-appattach-${appAttachStorageAccountName}'

  increaseStorageQuota: '${hpBaseName}-encryption-key-${increaseQuotaFAStorageAccountName}'
  sessionHostReplacement: '${hpBaseName}-encryption-key-${sessionHostReplacerFAStorageAccountName}'
  virtualMachines: '${hpBaseName}-encryption-key-vms'
  confidentialVMs: '${hpBaseName}-encryption-key-confidential-vms'
}
output smbServerLocation string = locationVirtualMachinesAbbreviation
output logAnalyticsWorkspaceName string = logAnalyticsWorkspaceName
output netAppAccountName string = netAppAccountName
output netAppCapacityPoolName string = netAppCapacityPoolName
output privateEndpointNameConv string = privateEndpointNameConv
output privateEndpointNICNameConv string = privateEndpointNICNameConv
output recoveryServicesVaultNames object = {
  fslogixStorage: replace(recoveryServicesVaultsNameConv, 'TOKEN-', 'fslogix-')
  virtualMachines: replace(recoveryServicesVaultsNameConv, 'TOKEN-', 'vms-')
}
output resourceGroupHosts string = resourceGroupHosts
output resourceGroupDeployment string = resourceGroupDeployment
output resourceGroupManagement string = resourceGroupManagement
output resourceGroupStorage string = resourceGroupStorage
output scalingPlanName string = scalingPlanName
output storageAccountNames object = {
  appAttach: appAttachStorageAccountName
  increaseStorageQuota: increaseQuotaFAStorageAccountName
  sessionHostReplacement: sessionHostReplacerFAStorageAccountName
}
output userAssignedIdentityNameConv string = userAssignedIdentityNameConv

output locations object = locations
