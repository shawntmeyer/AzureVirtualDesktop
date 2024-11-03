targetScope = 'subscription'

param avdPrivateLinkPrivateRoutes string
param envShortName string
param businessUnitIdentifier string
param centralizedAVDManagement bool
param existingFeedWorkspaceResourceId string
param fslogixStorageCustomPrefix string
param hostPoolIdentifier string
param locationControlPlane string
param locationGlobalFeed string
param locationVirtualMachines string
param nameConvResTypeAtEnd bool
param virtualMachineNamePrefix string

// Ensure that Centralized AVD Managment resource group and resources are created appropriately
var centralAVDManagement = !empty(businessUnitIdentifier) ? centralizedAVDManagement : true

var locations = (loadJsonContent('../../../.common/data/locations.json'))[environment().name]
var resourceAbbreviations = loadJsonContent('../../../.common/data/resourceAbbreviations.json')
var bUId = toLower(businessUnitIdentifier)
var hpId = toLower(hostPoolIdentifier)

var hpBaseName = !empty(bUId) ? '${bUId}-${hpId}' : hpId
var hpResPrfx = nameConvResTypeAtEnd ? hpBaseName : 'RESOURCETYPE-${hpBaseName}'

var nameConvSuffix = !empty(envShortName)
  ? (nameConvResTypeAtEnd ? '${envShortName}-LOCATION-RESOURCETYPE' : '${envShortName}-LOCATION')
  : (nameConvResTypeAtEnd ? 'LOCATION-RESOURCETYPE' : 'LOCATION')

var nameConv_HP_ResGroups = nameConvResTypeAtEnd
  ? 'avd-${hpBaseName}-TOKEN-${nameConvSuffix}'
  : 'RESOURCETYPE-avd-${hpBaseName}-TOKEN-${nameConvSuffix}'
var nameConv_HP_Resources = '${hpResPrfx}-TOKEN-${nameConvSuffix}'

// shared resources between host pools of same business unit, only used when centralizedAVDManagement is false
var nameConv_Shared_ResGroups = nameConvResTypeAtEnd
  ? (!empty(bUId) ? 'avd-${bUId}-TOKEN-${nameConvSuffix}' : 'avd-TOKEN-${nameConvSuffix}')
  : (!empty(bUId) ? 'RESOURCETYPE-avd-${bUId}-TOKEN-${nameConvSuffix}' : 'RESOURCETYPE-avd-TOKEN-${nameConvSuffix}')
var nameConv_Shared_Resources = nameConvResTypeAtEnd
  ? (!empty(bUId) ? '${bUId}-${nameConvSuffix}' : '${nameConvSuffix}')
  : (!empty(bUId) ? 'RESOURCETYPE-${bUId}-TOKEN-${nameConvSuffix}' : 'RESOURCETYPE-TOKEN-${nameConvSuffix}')
// Management and Monitoring Resource Naming Conventions
var nameConv_Management_ResGroup = centralAVDManagement
  ? (nameConvResTypeAtEnd ? 'avd-TOKEN-${nameConvSuffix}' : 'RESOURCETYPE-avd-TOKEN-${nameConvSuffix}')
  : nameConv_Shared_ResGroups
var nameConv_Management_Resources = centralAVDManagement
  ? (nameConvResTypeAtEnd ? 'avd-TOKEN-${nameConvSuffix}' : 'RESOURCETYPE-avd-TOKEN-${nameConvSuffix}')
  : nameConv_Shared_Resources

// Management and Monitoring Resource Names

var resourceGroupManagement = replace(
  replace(
    replace(nameConv_Management_ResGroup, 'TOKEN', 'management'),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'RESOURCETYPE',
  resourceAbbreviations.resourceGroups
)
var appServicePlanName = replace(
  replace(
    replace(nameConv_Management_Resources, 'RESOURCETYPE', resourceAbbreviations.appServicePlans),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'TOKEN-',
  ''
)
var keyVaultNameSecretsTemp = replace(
  replace(
    replace(nameConv_Management_Resources, 'RESOURCETYPE', resourceAbbreviations.keyVaults),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'TOKEN-',
  'secrets-'
)
var keyVaultNameSecrets = length(keyVaultNameSecretsTemp) > 24
  ? replace(keyVaultNameSecretsTemp, '-', '')
  : keyVaultNameSecretsTemp

// Monitoring Resources
var dataCollectionEndpointName = replace(
  replace(
    replace(nameConv_Management_Resources, 'RESOURCETYPE', resourceAbbreviations.dataCollectionEndpoints),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'TOKEN-',
  ''
)
// the AVD Insights data collection rule must start with 'microsoft-avdi-'
var dataCollectionRulesNameConv = replace(
  replace(
    replace(nameConv_Management_Resources, 'RESOURCETYPE', resourceAbbreviations.dataCollectionRules),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'TOKEN-',
  ''
)
var logAnalyticsWorkspaceName = replace(
  replace(
    replace(nameConv_Management_Resources, 'RESOURCETYPE', resourceAbbreviations.logAnalyticsWorkspaces),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'TOKEN-',
  ''
)

// Common Resource Naming Conventions
var appInsightsNameConv = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.applicationInsights),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)
var functionAppNameConv = replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.functionApps),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  )
var keyVaultHPNameConv = replace(
  replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.keyVaults),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)
var privateEndpointNameConv = replace(
  nameConvResTypeAtEnd ? 'RESOURCE-SUBRESOURCE-VNETID-RESOURCETYPE' : 'RESOURCETYPE-RESOURCE-SUBRESOURCE-VNETID',
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
var recoveryServicesVaultsNameConv = replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.recoveryServicesVaults),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  )
var userAssignedIdentityNameConv = replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.userAssignedIdentities),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  )

// Deployment Resources (temporary resource group for deployment purposes)
var resourceGroupDeployment = replace(
  replace(
    replace(nameConv_HP_ResGroups, 'TOKEN', 'deployment'),
    'LOCATION',
    '${locations[locationVirtualMachines].abbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
)
var depVirtualMachineNameTemp = replace(
  replace(
    replace(
      replace(nameConv_HP_Resources, 'RESOURCETYPE', ''),
      'LOCATION',
      locations[locationVirtualMachines].abbreviation
    ),
    'TOKEN-',
    ''
  ),
  '-',
  ''
)
var depVirtualMachineName = take('${depVirtualMachineNameTemp}${uniqueString(depVirtualMachineNameTemp)}', 15)
var depVirtualMachineDiskName = nameConvResTypeAtEnd
  ? '${depVirtualMachineName}-${resourceAbbreviations.disks}'
  : '${resourceAbbreviations.disks}-${depVirtualMachineName}'
var depVirtualMachineNicName = nameConvResTypeAtEnd
  ? '${depVirtualMachineName}-${resourceAbbreviations.networkInterfaces}'
  : '${resourceAbbreviations.networkInterfaces}-${depVirtualMachineName}'

// management and monitoring resources

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
  replace(
    replace(nameConv_HP_Resources, 'TOKEN-', ''),
    'RESOURCETYPE',
    resourceAbbreviations.desktopApplicationGroups
  ),
  'LOCATION',
  locations[locationControlPlane].abbreviation
)
var hostPoolName = replace(
  replace(replace(nameConv_HP_Resources, 'TOKEN-', ''), 'RESOURCETYPE', resourceAbbreviations.hostPools),
  'LOCATION',
  locations[locationControlPlane].abbreviation
)
var scalingPlanName = replace(
  replace(replace(nameConv_HP_Resources, 'TOKEN-', ''), 'RESOURCETYPE', resourceAbbreviations.scalingPlans),
  'LOCATION',
  locations[locationControlPlane].abbreviation
)
// Control Plane Shared Resources
var resourceGroupControlPlane = empty(existingFeedWorkspaceResourceId)
  ? replace(
      replace(
        replace(nameConv_Shared_ResGroups, 'TOKEN', 'control-plane'),
        'LOCATION',
        '${locations[locationControlPlane].abbreviation}'
      ),
      'RESOURCETYPE',
      '${resourceAbbreviations.resourceGroups}'
    )
  : split(existingFeedWorkspaceResourceId, '/')[4]

var workspaceName = empty(existingFeedWorkspaceResourceId)
  ? replace(
      replace(nameConv_Shared_Resources, 'RESOURCETYPE', resourceAbbreviations.workspaces),
      'LOCATION',
      locations[locationControlPlane].abbreviation
    )
  : last(split(existingFeedWorkspaceResourceId, '/'))

// Compute Resources
var resourceGroupHosts = replace(
  replace(
    replace(nameConv_HP_ResGroups, 'TOKEN', 'hosts'),
    'LOCATION',
    '${locations[locationVirtualMachines].abbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
)
var vmNamePrefixWithoutDash = toLower(last(virtualMachineNamePrefix) == '-'
  ? take(virtualMachineNamePrefix, length(virtualMachineNamePrefix) - 1)
  : virtualMachineNamePrefix)
var availabilitySetNamePrefix = nameConvResTypeAtEnd
  ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.availabilitySets}-'
  : '${resourceAbbreviations.availabilitySets}-${vmNamePrefixWithoutDash}-'

var diskNamePrefix = nameConvResTypeAtEnd
  ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.disks}-'
  : '${resourceAbbreviations.disks}-${vmNamePrefixWithoutDash}-'
var networkInterfaceNamePrefix = nameConvResTypeAtEnd
  ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.networkInterfaces}-'
  : '${resourceAbbreviations.networkInterfaces}-${vmNamePrefixWithoutDash}-'
var diskAccessName = replace(
  replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.diskAccesses),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'TOKEN-',
  ''
)
// Disk Encryption Set Names - Max length 80 Characters
var diskEncryptionSetNameConv = replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.diskEncryptionSets),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  )
var keyVaultNameVMs = length(replace(keyVaultHPNameConv, 'TOKEN-', 'vm-')) > 24
  ? replace(replace(keyVaultHPNameConv, 'TOKEN-', 'vm-'), '-', '')
  : replace(keyVaultHPNameConv, 'TOKEN-', 'vm-')
var keyVaultNameSHR = length(replace(keyVaultHPNameConv, 'TOKEN-', 'shr-')) > 24
  ? replace(replace(keyVaultHPNameConv, 'TOKEN-', 'shr-'), '-', '')
  : replace(keyVaultHPNameConv, 'TOKEN-', 'shr-')

// Storage Resources
var resourceGroupStorage = replace(
  replace(
    replace(nameConv_HP_ResGroups, 'TOKEN', 'storage'),
    'LOCATION',
    '${locations[locationVirtualMachines].abbreviation}'
  ),
  'RESOURCETYPE',
  '${resourceAbbreviations.resourceGroups}'
)

var storageAccountNameConv = replace(replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.storageAccounts),
  'LOCATION',
  locations[locationVirtualMachines].abbreviation
)

var netAppAccountName = replace(
  replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.netAppAccounts),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'TOKEN-',
  ''
)
var netAppCapacityPoolName = replace(
  replace(
    replace(nameConv_HP_Resources, 'RESOURCETYPE', resourceAbbreviations.netAppCapacityPools),
    'LOCATION',
    locations[locationVirtualMachines].abbreviation
  ),
  'TOKEN-',
  ''
)
// Storage Account Naming Prefix
var fslogixStorageAccountNamePrefix = empty(fslogixStorageCustomPrefix)
  ? toLower('${replace(replace(replace(replace(replace(replace(nameConv_HP_Resources, 'RESOURCETYPE', ''), hpBaseName, '${hpBaseName}ud'), 'LOCATION', locations[locationVirtualMachines].abbreviation), 'TOKEN-', ''), 'avd-', ''), '-', '')}')
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

var keyVaultNameIncreaseQuota = length(replace(keyVaultHPNameConv, 'TOKEN-', 'stquota-')) > 24
  ? replace(replace(keyVaultHPNameConv, '-TOKEN-', '-stquota-'), '-', '')
  : replace(keyVaultHPNameConv, 'TOKEN-', 'stquota-')

var keyVaultNameConvStorage = length(replace(
    replace(
      nameConvResTypeAtEnd
        ? 'STORAGEACCOUNTNAME-${nameConvSuffix}'
        : 'RESOURCETYPE-STORAGEACCOUNTNAME-${nameConvSuffix}',
      'LOCATION',
      locations[locationVirtualMachines].abbreviation
    ),
    'RESOURCETYPE',
    resourceAbbreviations.keyVaults
  )) > 24
  ? replace(
      replace(
        replace(
          nameConvResTypeAtEnd
            ? 'STORAGEACCOUNTNAME-${nameConvSuffix}'
            : 'RESOURCETYPE-STORAGEACCOUNTNAME-${nameConvSuffix}',
          'LOCATION',
          locations[locationVirtualMachines].abbreviation
        ),
        'RESOURCETYPE',
        resourceAbbreviations.keyVaults
      ),
      '-',
      ''
    )
  : replace(
      replace(
        nameConvResTypeAtEnd
          ? 'STORAGEACCOUNTNAME-${nameConvSuffix}'
          : 'RESOURCETYPE-STORAGEACCOUNTNAME-${nameConvSuffix}',
        'LOCATION',
        locations[locationVirtualMachines].abbreviation
      ),
      'RESOURCETYPE',
      resourceAbbreviations.keyVaults
    )

output appInsightsNames object = {
  IncreaseStorageQuota: replace(appInsightsNameConv, 'TOKEN-', 'stquota-')
  SessionHostReplacement: replace(appInsightsNameConv, 'TOKEN-', 'shr-')
}
output appServicePlanName string = appServicePlanName
output availabilitySetNamePrefix string = availabilitySetNamePrefix
output dataCollectionEndpointName string = dataCollectionEndpointName
output dataCollectionRulesNameConv string = dataCollectionRulesNameConv
output depVirtualMachineName string = depVirtualMachineName
output depVirtualMachineNicName string = depVirtualMachineNicName
output depVirtualMachineDiskName string = depVirtualMachineDiskName
output desktopApplicationGroupName string = desktopApplicationGroupName
output diskAccessName string = diskAccessName
output diskEncryptionSetNames object = {
  ConfidentialVMs: replace(diskEncryptionSetNameConv, 'TOKEN-', 'confvm-customer-keys-')
  CustomerManaged: replace(diskEncryptionSetNameConv, 'TOKEN-', 'customer-keys-')
  PlatformAndCustomerManaged: replace(diskEncryptionSetNameConv, 'TOKEN-', 'platform-and-customer-keys-')
}
output diskNamePrefix string = diskNamePrefix
output fslogixFileShareNames object = fslogixfileShareNames
output functionAppNames object = {
  IncreaseStorageQuota: replace(functionAppNameConv, 'TOKEN-', 'stquota-')
  SessionHostReplacement: replace(functionAppNameConv, 'TOKEN-', 'shr-')
}
output globalFeedWorkspaceName string = globalFeedWorkspaceName
output hostPoolName string = hostPoolName
output keyVaultNames object = {
  FSLogixStorageAccountEncryptionKeysNameConv: keyVaultNameConvStorage
  IncreaseStorageQuota: keyVaultNameIncreaseQuota
  SessionHostReplacement: keyVaultNameSHR
  VMEncryptionKeys: keyVaultNameVMs
  VMSecrets: keyVaultNameSecrets
}
output locations object = locations
output logAnalyticsWorkspaceName string = logAnalyticsWorkspaceName
output netAppAccountName string = netAppAccountName
output netAppCapacityPoolName string = netAppCapacityPoolName
output networkInterfaceNamePrefix string = networkInterfaceNamePrefix
output privateEndpointNameConv string = privateEndpointNameConv
output privateEndpointNICNameConv string = privateEndpointNICNameConv
output recoveryServicesVaultNames object = {
  FSLogixStorage: replace(recoveryServicesVaultsNameConv, 'TOKEN-', 'fslogix-storage-')
  VirtualMachines: replace(recoveryServicesVaultsNameConv, 'TOKEN-', 'virtual-machines-')
}
output resourceGroupControlPlane string = resourceGroupControlPlane
output resourceGroupGlobalFeed string = globalFeedResourceGroupName
output resourceGroupHosts string = resourceGroupHosts
output resourceGroupDeployment string = resourceGroupDeployment
output resourceGroupManagement string = resourceGroupManagement
output resourceGroupStorage string = resourceGroupStorage
output scalingPlanName string = scalingPlanName
output storageAccountNames object = {
  FSLogix: fslogixStorageAccountNamePrefix
  IncreaseStorageQuota: toLower(replace(replace(storageAccountNameConv, 'TOKEN-', 'stquota'), '-', ''))
  SessionHostReplacement: toLower(replace(replace(storageAccountNameConv, 'TOKEN-', 'shr'), '-', ''))
}
output userAssignedIdentityNameConv string = userAssignedIdentityNameConv
output virtualMachineNamePrefix string = virtualMachineNamePrefix
output workspaceName string = workspaceName
