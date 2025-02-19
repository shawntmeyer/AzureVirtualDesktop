targetScope = 'subscription'

@description('The region to deploy the network resources to.')
param location string = deployment().location

@description('Determines whether or not to deploy the virtual network.')
param deployVnet bool = false

@description('Determines whether or not to deploy the resource group for the virtual network.')
param deployVnetResourceGroup bool = false

@description('Conditional. The name of the resource group to deploy the virtual network to. Required when "deployVnet" is "true".')
param vnetResourceGroupName string = ''

@description('Conditional. The name of the virtual network. Required when "deployVnet" is "true".')
param vnetName string = ''

@description('Conditional. The address prefixes for the virtual network. Required when "deployVnet" is "true".')
param vnetAddressPrefixes array = []

@description('Conditional. The hosts subnet to create within the virtual network. Required when "deployVnet" is "true".')
param hostsSubnet object = {}

@description('Optional. The private endpoint subnet to create within the virtual network.')
param privateEndpointsSubnet object = {}

@description('Optional. The function app subnet to create within the virtual network.')
param functionAppSubnet object = {}

@description('Optional. The type of default routing used on the subnets.')
@allowed([
  'default'
  'nva'
  'nat'
])
param defaultRouting string = 'default'

@description('Optional. Determines if the resources should be named with the resource type at the end.')
param nameConvResTypeAtEnd bool = false

@description('Conditional. The IP Address the network virtual appliance. Required when "defaultRouting" is "nva".')
param nvaIPAddress string = ''

@description('Optional. The custom DNS servers to use for the virtual network.')
param customDNSServers array = []

@description('Optional. Determines if DDoS network protection should be deployed.')
param deployDDoSNetworkProtection bool = false

@description('Optional. The resource id of the hub virtual network to which the virtual network should be peered.')
param hubVnetResourceId string = ''

@description('Optional. Determines if a virtual network gateway is present on the hub virtual network.')
param virtualNetworkGatewayOnHub bool = false

@description('Optional. The subscription id of the subscription to where the private DNS zones should be deployed.')
param privateDNSZonesSubscriptionId string = subscription().subscriptionId

@description('Optional. Determines if the private DNS zones resource group should be deployed.')
param deployPrivateDNSZonesResourceGroup bool = false

@description('Conditional. The name of the private DNS zones resource group. Required when any of the private DNS Zones are deployed based on the "createZone" parameters.')
param privateDNSZonesResourceGroupName string = ''

@description('Optional. Determines if the Azure Backup private DNS zone should be created.')
param createAzureBackupZone bool = false

@description('Optional. Determines if the Azure Blob Storage private DNS zone should be created.')
param createAzureBlobZone bool = false

@description('Optional. Determines if the Azure Files Storage private DNS zone should be created.')
param createAzureFilesZone bool = false

@description('Optional. Determines if the Azure Queue Storage private DNS zone should be created.')
param createAzureQueueZone bool = false

@description('Optional. Determines if the Azure Table Storage private DNS zone should be created.')
param createAzureTableZone bool = false

@description('Optional. Determines if the Azure Key Vault private DNS zone should be created.')
param createAzureKeyVaultZone bool = false

@description('Optional. Determines if the AVD feed private DNS zone should be created.')
param createAvdFeedZone bool = false

@description('Optional. Determines if the AVD global feed private DNS zone should be created.')
param createAvdGlobalFeedZone bool = false

@description('Optional. Determines if the Azure Web App private DNS zone should be created.')
param createAzureWebAppZone bool = false

@description('Optional. Determines if the Azure Web App SCM private DNS zone should be created.')
param createAzureWebAppScmZone bool = false

@description('Optional. Determines if the private DNS zones should be linked to a new virtual network.')
param linkPrivateDnsZonesToNewVnet bool = false

@description('Conditional. The resource id of the virtual network to link the private DNS zones to. Required when "linkPrivateDnsZonesToNewVnet" is "false" and any of the private DNS Zones are deployed.')
param privateDnsZonesVnetId string = ''

@description('Optional. The tags by resource type to apply to the resources.')
param tags object = {}

// Non Specified Values
@description('DO NOT MODIFY THIS VALUE! The timeStamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param timeStamp string = utcNow('yyyyMMddhhmmss')

var createPrivateDNSZones = createAzureBackupZone || createAzureBlobZone || createAzureFilesZone || createAzureQueueZone || createAzureTableZone || createAzureKeyVaultZone || createAvdFeedZone || createAvdGlobalFeedZone || createAzureWebAppZone || createAzureWebAppScmZone
var locations = (loadJsonContent('../../.common/data/locations.json'))[environment().name]
var resourceAbbreviations = loadJsonContent('../../.common/data/resourceAbbreviations.json')
var nameConvSuffix = nameConvResTypeAtEnd ? 'LOCATION-RESOURCETYPE' : 'LOCATION'

var nameConv_Shared_Resources = nameConvResTypeAtEnd
  ? 'avd-TOKEN-${nameConvSuffix}'
  : 'RESOURCETYPE-avd-TOKEN-${nameConvSuffix}'
var natGatewayName = replace(
  replace(
    replace(nameConv_Shared_Resources, 'RESOURCETYPE', resourceAbbreviations.natGateways),
    'LOCATION',
    locations[location].abbreviation
  ),
  'TOKEN-',
  ''
)
var publicIPName = replace(
  replace(
    replace(nameConv_Shared_Resources, 'RESOURCETYPE', resourceAbbreviations.publicIPAddresses),
    'LOCATION',
    locations[location].abbreviation
  ),
  'TOKEN-',
  ''
)
var routeTableName = replace(
  replace(
    replace(nameConv_Shared_Resources, 'RESOURCETYPE', resourceAbbreviations.routeTables),
    'LOCATION',
    locations[location].abbreviation
  ),
  'TOKEN-',
  ''
)

var hubSubscriptionId = !empty(hubVnetResourceId) ? split(hubVnetResourceId, '/')[2] : ''
var hubVnetResourceGroup = !empty(hubVnetResourceId) ? split(hubVnetResourceId, '/')[4] : ''
var hubVnetName = !empty(hubVnetResourceId) ? last(split(hubVnetResourceId, '/')) : ''

var backupPrivateDnsZone = createAzureBackupZone
  ? filter(privateDNSZoneNames.outputs.zoneNames, (name) => contains(name, '.backup.'))
  : []
var blobPrivateDnsZone = createAzureBlobZone
  ? filter(privateDNSZoneNames.outputs.zoneNames, (name) => contains(name, '.blob.'))
  : []
var filesPrivateDnsZone = createAzureFilesZone
  ? filter(privateDNSZoneNames.outputs.zoneNames, (name) => contains(name, '.file.'))
  : []
var queuePrivateDnsZone = createAzureQueueZone
  ? filter(privateDNSZoneNames.outputs.zoneNames, (name) => contains(name, '.queue.'))
  : []
var tablePrivateDnsZone = createAzureTableZone
  ? filter(privateDNSZoneNames.outputs.zoneNames, (name) => contains(name, '.table.'))
  : []
var keyVaultPrivateDnsZone = createAzureKeyVaultZone
  ? filter(privateDNSZoneNames.outputs.zoneNames, (name) => contains(name, '.vaultcore.'))
  : []
var avdFeedPrivateDnsZone = createAvdFeedZone
  ? filter(privateDNSZoneNames.outputs.zoneNames, (name) => contains(name, 'privatelink.wvd.'))
  : []
var avdGlobalFeedPrivateDnsZone = createAvdGlobalFeedZone
  ? filter(privateDNSZoneNames.outputs.zoneNames, (name) => contains(name, 'privatelink-global.wvd.'))
  : []
var webAppPrivateDnsZone = createAzureWebAppZone
  ? filter(
      privateDNSZoneNames.outputs.zoneNames,
      (name) => contains(name, '.azurewebsites.') || contains(name, '.appservice.')
    )
  : []
var webAppScmPrivateDnsZone = createAzureWebAppScmZone
  ? filter(privateDNSZoneNames.outputs.zoneNames, (name) => contains(name, '.scm.'))
  : []
var privateDnsZonesToCreate = union(
  backupPrivateDnsZone,
  blobPrivateDnsZone,
  filesPrivateDnsZone,
  queuePrivateDnsZone,
  tablePrivateDnsZone,
  keyVaultPrivateDnsZone,
  avdFeedPrivateDnsZone,
  avdGlobalFeedPrivateDnsZone,
  webAppPrivateDnsZone,
  webAppScmPrivateDnsZone
)

resource vNetResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = if (deployVnetResourceGroup) {
  name: vnetResourceGroupName
  location: location
  tags: tags[?'Microsoft.Resources/resourceGroups'] ?? {} 
}

module network 'modules/networks.bicep' = if (deployVnet) {
  scope: resourceGroup(vnetResourceGroupName)
  name: 'Network-Resources-${timeStamp}'
  params: {
    customDNSServers: customDNSServers
    defaultRouting: defaultRouting
    deployDDoSNetworkProtection: deployDDoSNetworkProtection
    functionAppSubnet: functionAppSubnet
    hostsSubnet: hostsSubnet
    hubVnetName: hubVnetName
    hubVnetResourceGroup: hubVnetResourceGroup
    hubVnetSubscriptionId: hubSubscriptionId
    location: location
    natGatewayName: natGatewayName
    nvaIPAddress: nvaIPAddress
    privateEndpointsSubnet: privateEndpointsSubnet
    publicIPName: publicIPName
    routeTableName: routeTableName
    tags: tags
    timeStamp: timeStamp
    virtualNetworkGatewayOnHub: virtualNetworkGatewayOnHub
    vnetAddressPrefixes: vnetAddressPrefixes
    vnetName: vnetName
  }
  dependsOn: [
    vNetResourceGroup
  ]
}

module privateDNSZoneNames 'modules/privateDnsZoneNames.bicep' = {
  name: 'Private-Dns-Zone-Names-${timeStamp}'
  scope: subscription()
  params: {
    locations: locations
  }
}

module privateDNSZonesResourceGroup '../sharedModules/resources/resources/resource-group/main.bicep' = if (createPrivateDNSZones && deployPrivateDNSZonesResourceGroup) {
  name: 'Private-DNS-Zones-ResourceGroup-${timeStamp}'
  scope: subscription(privateDNSZonesSubscriptionId)
  params: {
    name: privateDNSZonesResourceGroupName
    location: location
    tags: tags[?'Microsoft.Resources/resourceGroups'] ?? {}
  }
  dependsOn: [
    network
    privateDNSZoneNames
  ]
}

module privateDNSZones 'modules/privateDnsZones.bicep' = if(createPrivateDNSZones) {
  name: 'Private-DNS-Zones-${timeStamp}'
  scope: resourceGroup(privateDNSZonesSubscriptionId, privateDNSZonesResourceGroupName)
  params: {
    privateDnsZoneNames: privateDnsZonesToCreate
    tags: tags
    vnetId: !empty(privateDnsZonesVnetId) ? privateDnsZonesVnetId : ( linkPrivateDnsZonesToNewVnet ? network.outputs.vnetResourceId : '' )
  }
  dependsOn: [
    privateDNSZonesResourceGroup
  ]
}
