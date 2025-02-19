targetScope = 'subscription'

param identitySolution string
param avdPrivateDnsZoneResourceId string
param avdPrivateLinkPrivateRoutes string
param hostPoolRDPProperties string
param deployScalingPlan bool
param deploymentUserAssignedIdentityClientId string
param desktopApplicationGroupName string
param desktopFriendlyName string
param existingGlobalWorkspaceResourceId string
param existingFeedWorkspaceResourceId string
param globalWorkspaceName string
param hostPoolName string
param hostPoolType string
param locationControlPlane string
param locationGlobalFeed string
param locationVirtualMachines string
param logAnalyticsWorkspaceResourceId string
param deploymentVirtualMachineName string
param hostPoolMaxSessionLimit int
param hostPoolPublicNetworkAccess string
param enableMonitoring bool
param privateEndpointNameConv string
param privateEndpointNICNameConv string
param globalFeedPrivateDnsZoneResourceId string
param globalFeedPrivateEndpointSubnetResourceId string
param hostPoolPrivateEndpointSubnetResourceId string
param resourceGroupControlPlane string
param resourceGroupGlobalFeed string
param resourceGroupDeployment string
param roleDefinitions object
param scalingPlanExclusionTag string
param scalingPlanName string
param scalingPlanSchedules array
param appGroupSecurityGroups array
param tags object
param timeStamp string
param hostPoolValidationEnvironment bool
param virtualMachineTemplate string
param virtualMachinesTimeZone string
param workspaceFriendlyName string
param workspaceName string
param workspaceFeedPrivateEndpointSubnetResourceId string
param workspacePublicNetworkAccess string

var feedPrivateEndpointName = ( avdPrivateLinkPrivateRoutes != 'None' || avdPrivateLinkPrivateRoutes != 'HostPool' ) && !empty(workspaceFeedPrivateEndpointSubnetResourceId) ? replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'feed'), 'RESOURCE', workspaceName), 'VNETID', '${split(workspaceFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'feedPrivateEndpointName'
var feedPrivateEndpointNICName = ( avdPrivateLinkPrivateRoutes != 'None' || avdPrivateLinkPrivateRoutes != 'HostPool' )  && !empty(workspaceFeedPrivateEndpointSubnetResourceId) ? replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'feed'), 'RESOURCE', workspaceName), 'VNETID', '${split(workspaceFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'feedPrivateEndpointName'
var globalFeedPrivateEndpointName = avdPrivateLinkPrivateRoutes == 'All' && !empty(globalFeedPrivateEndpointSubnetResourceId) ? replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'global'), 'RESOURCE', workspaceName), 'VNETID', '${split(globalFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'globalFeedPrivateEndpointName'
var globalFeedPrivateEndpointNICName = avdPrivateLinkPrivateRoutes == 'All' && !empty(globalFeedPrivateEndpointSubnetResourceId) ? replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'global'), 'RESOURCE', workspaceName), 'VNETID', '${split(globalFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'globalFeedPrivateEndpointName'
var hostPoolPrivateEndpointName = avdPrivateLinkPrivateRoutes != 'None' && !empty(hostPoolPrivateEndpointSubnetResourceId) ? replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'connection'), 'RESOURCE', hostPoolName), 'VNETID', '${split(hostPoolPrivateEndpointSubnetResourceId, '/')[8]}') : 'hostPoolPrivateEndpointName'
var hostPoolPrivateEndpointNICName = avdPrivateLinkPrivateRoutes != 'None' && !empty(hostPoolPrivateEndpointSubnetResourceId) ? replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'connection'), 'RESOURCE', hostPoolName), 'VNETID', '${split(hostPoolPrivateEndpointSubnetResourceId, '/')[8]}') : 'hostPoolPrivateEndpointName'

module hostPoolPrivateEndpointVnet '../common/vnetLocation.bicep' = if (avdPrivateLinkPrivateRoutes != 'None' && !empty(hostPoolPrivateEndpointSubnetResourceId)) {
  name: 'HostPoolPrivateEndpointVnet_${timeStamp}'
  params: {
    privateEndpointSubnetResourceId: hostPoolPrivateEndpointSubnetResourceId
  }
}

module workspaceFeedPrivateEndpointVnet '../common/vnetLocation.bicep' = if ((avdPrivateLinkPrivateRoutes == 'All' || avdPrivateLinkPrivateRoutes == 'FeedAndHostPool') && !empty(workspaceFeedPrivateEndpointSubnetResourceId)) {
  name: 'WorkspaceFeedPrivateEndpointVnet_${timeStamp}'
  params: {
    privateEndpointSubnetResourceId: workspaceFeedPrivateEndpointSubnetResourceId
  }
}

module globalFeedPrivateEndpointVnet '../common/vnetLocation.bicep' = if (avdPrivateLinkPrivateRoutes == 'All' && !empty(globalFeedPrivateEndpointSubnetResourceId)) {
  name: 'GlobalFeedPrivateEndpointVnet_${timeStamp}'
  params: {
    privateEndpointSubnetResourceId: globalFeedPrivateEndpointSubnetResourceId
  }
}

module hostPool 'modules/hostPool.bicep' = {
  name: 'HostPool_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    identitySolution: identitySolution    
    hostPoolRDPProperties: hostPoolRDPProperties
    hostPoolName: hostPoolName
    hostPoolPrivateDnsZoneResourceId: avdPrivateDnsZoneResourceId
    hostPoolPublicNetworkAccess: hostPoolPublicNetworkAccess
    hostPoolType: hostPoolType
    hostPoolValidationEnvironment: hostPoolValidationEnvironment
    location: locationControlPlane
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    hostPoolMaxSessionLimit: hostPoolMaxSessionLimit
    enableMonitoring: enableMonitoring
    privateEndpoint: avdPrivateLinkPrivateRoutes != 'None' ? true : false
    privateEndpointLocation: avdPrivateLinkPrivateRoutes != 'None' && !empty(hostPoolPrivateEndpointSubnetResourceId) ? hostPoolPrivateEndpointVnet.outputs.location : ''    
    privateEndpointName: hostPoolPrivateEndpointName
    privateEndpointNICName: hostPoolPrivateEndpointNICName
    privateEndpointSubnetResourceId: hostPoolPrivateEndpointSubnetResourceId
    tags: tags
    timeStamp: timeStamp
    virtualMachineTemplate: virtualMachineTemplate
  }
}

module applicationGroup 'modules/applicationGroup.bicep' = {
  name: 'ApplicationGroup_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    desktopApplicationGroupName: desktopApplicationGroupName
    desktopFriendlyName: desktopFriendlyName
    hostPoolResourceId: hostPool.outputs.resourceId
    location: locationControlPlane
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    deploymentVirtualMachineName: deploymentVirtualMachineName
    resourceGroupDeployment: resourceGroupDeployment
    roleDefinitions: roleDefinitions
    appGroupSecurityGroups: appGroupSecurityGroups
    tags: tags  
    timeStamp: timeStamp
  }
}

module feedWorkspace 'modules/workspace.bicep' = {
  name: 'WorkspaceFeed_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    applicationGroupResourceId: applicationGroup.outputs.ApplicationGroupResourceId
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    enableMonitoring: enableMonitoring
    existingWorkspaceResourceId: existingFeedWorkspaceResourceId
    friendlyName: workspaceFriendlyName
    groupIds: ['feed']
    location: locationControlPlane
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    deploymentVirtualMachineName: deploymentVirtualMachineName
    privateDnsZoneResourceId: avdPrivateDnsZoneResourceId
    privateEndpoint: avdPrivateLinkPrivateRoutes != 'None' || avdPrivateLinkPrivateRoutes != 'HostPool' ? true : false
    privateEndpointLocation: !empty(workspaceFeedPrivateEndpointSubnetResourceId) ? workspaceFeedPrivateEndpointVnet.outputs.location : ''
    privateEndpointName: feedPrivateEndpointName
    privateEndpointNICName: feedPrivateEndpointNICName
    privateEndpointSubnetResourceId: workspaceFeedPrivateEndpointSubnetResourceId
    publicNetworkAccess: workspacePublicNetworkAccess
    resourceGroupDeployment: resourceGroupDeployment
    tags: tags
    timeStamp: timeStamp
    workspaceName: workspaceName    
  }
}

module scalingPlan 'modules/scalingPlan.bicep' = if(deployScalingPlan && contains(hostPoolType,'Pooled')) {
  name: 'ScalingPlan_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    diagnosticWorkspaceId: logAnalyticsWorkspaceResourceId
    exclusionTag: scalingPlanExclusionTag
    hostPoolResourceId: hostPool.outputs.resourceId
    hostPoolType: split(hostPoolType, ' ')[0]
    location: locationVirtualMachines
    name: scalingPlanName
    schedules: scalingPlanSchedules
    tags: tags
    timeZone: virtualMachinesTimeZone
  }
} 

module globalWorkspace 'modules/workspace.bicep' = if(empty(existingGlobalWorkspaceResourceId) && avdPrivateLinkPrivateRoutes == 'All' && !empty(globalFeedPrivateDnsZoneResourceId) && !empty(globalFeedPrivateEndpointSubnetResourceId)) {
  name: 'Global_Feed_Workspace_${timeStamp}'
  scope: resourceGroup(resourceGroupGlobalFeed)
  params: {
    applicationGroupResourceId: ''
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    enableMonitoring: enableMonitoring
    existingWorkspaceResourceId: existingGlobalWorkspaceResourceId
    friendlyName: ''
    groupIds: ['global']
    location: locationGlobalFeed
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    deploymentVirtualMachineName: deploymentVirtualMachineName
    privateDnsZoneResourceId: globalFeedPrivateDnsZoneResourceId
    privateEndpoint: true
    privateEndpointLocation: !empty(globalFeedPrivateEndpointSubnetResourceId) ? globalFeedPrivateEndpointVnet.outputs.location : ''
    privateEndpointName: globalFeedPrivateEndpointName
    privateEndpointNICName: globalFeedPrivateEndpointNICName
    privateEndpointSubnetResourceId: globalFeedPrivateEndpointSubnetResourceId
    publicNetworkAccess: 'Enabled'  
    resourceGroupDeployment: resourceGroupDeployment
    tags: tags
    timeStamp: timeStamp
    workspaceName: globalWorkspaceName
  }
  dependsOn: [
    feedWorkspace
  ]
}

output hostPoolResourceId string = hostPool.outputs.resourceId
