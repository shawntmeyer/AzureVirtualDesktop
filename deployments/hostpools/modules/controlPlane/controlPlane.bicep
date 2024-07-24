targetScope = 'subscription'

param identitySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param avdPrivateDnsZoneResourceId string
param avdPrivateLinkPrivateRoutes string
param hostPoolRDPProperties string
param deployScalingPlan bool
param deploymentUserAssignedIdentityClientId string
param desktopApplicationGroupName string
param desktopFriendlyName string
param existingGlobalWorkspace bool
param existingFeedWorkspaceResourceId string
param globalWorkspaceName string
param hostPoolName string
param hostPoolType string
param locationControlPlane string
param locationGlobalFeed string
param locationVirtualMachines string
param logAnalyticsWorkspaceResourceId string
param managementVirtualMachineName string
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
param resourceGroupManagement string
param roleDefinitions object
param scalingPlanExclusionTag string
param scalingPlanName string
param scalingPlanSchedules array
param securityPrincipalObjectIds array
param tags object
param timeStamp string
param hostPoolValidationEnvironment bool
param virtualMachineTemplate string
param virtualMachinesTimeZone string
param workspaceFriendlyName string
param workspaceName string
param workspaceFeedPrivateEndpointSubnetResourceId string
param workspacePublicNetworkAccess string

var feedPrivateEndpointName = avdPrivateLinkPrivateRoutes != 'None' || avdPrivateLinkPrivateRoutes != 'HostPool' ? replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'feed'), 'RESOURCE', workspaceName), 'VNETID', '${split(workspaceFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'feedPrivateEndpointName'
var feedPrivateEndpointNICName = avdPrivateLinkPrivateRoutes != 'None' || avdPrivateLinkPrivateRoutes != 'HostPool' ? replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'feed'), 'RESOURCE', workspaceName), 'VNETID', '${split(workspaceFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'feedPrivateEndpointName'
var globalFeedPrivateEndpointName = avdPrivateLinkPrivateRoutes == 'All' ? replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'global'), 'RESOURCE', workspaceName), 'VNETID', '${split(globalFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'globalFeedPrivateEndpointName'
var globalFeedPrivateEndpointNICName = avdPrivateLinkPrivateRoutes == 'All' ? replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'global'), 'RESOURCE', workspaceName), 'VNETID', '${split(globalFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'globalFeedPrivateEndpointName'
var hostPoolPrivateEndpointName = avdPrivateLinkPrivateRoutes != 'None' ? replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'connection'), 'RESOURCE', hostPoolName), 'VNETID', '${split(hostPoolPrivateEndpointSubnetResourceId, '/')[8]}') : 'hostPoolPrivateEndpointName'
var hostPoolPrivateEndpointNICName = avdPrivateLinkPrivateRoutes != 'None' ? replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'connection'), 'RESOURCE', hostPoolName), 'VNETID', '${split(hostPoolPrivateEndpointSubnetResourceId, '/')[8]}') : 'hostPoolPrivateEndpointName'


module hostPool 'hostPool.bicep' = {
  name: 'HostPool_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    identitySolution: identitySolution
    avdPrivateLink: avdPrivateLinkPrivateRoutes != 'None' ? true : false
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
    privateEndpointName: hostPoolPrivateEndpointName
    privateEndpointNICName: hostPoolPrivateEndpointNICName
    privateEndpointSubnetResourceId: hostPoolPrivateEndpointSubnetResourceId
    tags: tags
    timeStamp: timeStamp
    virtualMachineTemplate: virtualMachineTemplate
  }
}

module applicationGroup 'applicationGroup.bicep' = {
  name: 'ApplicationGroup_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    desktopApplicationGroupName: desktopApplicationGroupName
    desktopFriendlyName: desktopFriendlyName
    hostPoolResourceId: hostPool.outputs.resourceId
    location: locationControlPlane
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    managementVirtualMachineName: managementVirtualMachineName
    resourceGroupManagement: resourceGroupManagement
    roleDefinitions: roleDefinitions
    securityPrincipalObjectIds: securityPrincipalObjectIds
    tags: tags  
    timeStamp: timeStamp
  }
}

module feedWorkspace 'workspace.bicep' = {
  name: 'WorkspaceFeed_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    applicationGroupReferences: applicationGroup.outputs.ApplicationGroupReference
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    avdPrivateLink: avdPrivateLinkPrivateRoutes != 'None' || avdPrivateLinkPrivateRoutes != 'HostPool' ? true : false
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    enableMonitoring: enableMonitoring
    existingWorkspace: !empty(existingFeedWorkspaceResourceId) ? true : false
    friendlyName: workspaceFriendlyName
    groupIds: ['feed']
    location: locationControlPlane
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    managementVirtualMachineName: managementVirtualMachineName
    privateDnsZoneResourceId: avdPrivateDnsZoneResourceId
    privateEndpointName: feedPrivateEndpointName
    privateEndpointNICName: feedPrivateEndpointNICName
    privateEndpointSubnetResourceId: workspaceFeedPrivateEndpointSubnetResourceId
    publicNetworkAccess: workspacePublicNetworkAccess
    resourceGroupManagement: resourceGroupManagement
    tags: tags
    timeStamp: timeStamp
    workspaceName: workspaceName    
  }
}

module scalingPlan 'scalingPlan.bicep' = if(deployScalingPlan && contains(hostPoolType,'Pooled')) {
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

module globalWorkspace 'workspace.bicep' = if(!existingGlobalWorkspace && avdPrivateLinkPrivateRoutes == 'All' && !empty(globalFeedPrivateDnsZoneResourceId) && !empty(globalFeedPrivateEndpointSubnetResourceId)) {
  name: 'Global_Feed_Workspace_${timeStamp}'
  scope: resourceGroup(resourceGroupGlobalFeed)
  params: {
    applicationGroupReferences: []
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    avdPrivateLink: true
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    enableMonitoring: enableMonitoring
    existingWorkspace: existingGlobalWorkspace
    friendlyName: ''
    groupIds: ['global']
    location: locationGlobalFeed
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    managementVirtualMachineName: managementVirtualMachineName
    privateDnsZoneResourceId: globalFeedPrivateDnsZoneResourceId
    privateEndpointName: globalFeedPrivateEndpointName
    privateEndpointNICName: globalFeedPrivateEndpointNICName
    privateEndpointSubnetResourceId: globalFeedPrivateEndpointSubnetResourceId
    publicNetworkAccess: 'Enabled'  
    resourceGroupManagement: resourceGroupManagement
    tags: tags
    timeStamp: timeStamp
    workspaceName: globalWorkspaceName
  }
  dependsOn: [
    feedWorkspace
  ]
}

output hostPoolName string = last(split(hostPool.outputs.resourceId, '/'))
output hostPoolRegistrationToken string = hostPool.outputs.registrationToken
