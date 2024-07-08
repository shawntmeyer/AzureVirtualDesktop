targetScope = 'subscription'

param identitySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param avdGlobalFeedPrivateDnsZoneResourceId string
param avdPrivateDnsZoneResourceId string
param avdPrivateLink bool
param hostPoolRDPProperties string
param deployScalingPlan bool
param deploymentUserAssignedIdentityClientId string
param desktopApplicationGroupName string
param desktopFriendlyName string
param existingGlobalWorkspace bool
param existingWorkspace bool
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
param globalFeedPrivateEndpointSubnetResourceId string
param feedPrivateEndpointSubnetResourceId string
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
param workspacePublicNetworkAccess string

var feedPrivateEndpointName = avdPrivateLink ? replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'feed'), 'RESOURCE', workspaceName), 'VNETID', '${split(feedPrivateEndpointSubnetResourceId, '/')[8]}') : 'feedPrivateEndpointName'
var feedPrivateEndpointNICName = avdPrivateLink ? replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'feed'), 'RESOURCE', workspaceName), 'VNETID', '${split(feedPrivateEndpointSubnetResourceId, '/')[8]}') : 'feedPrivateEndpointName'
var globalFeedPrivateEndpointName = avdPrivateLink ? replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'global'), 'RESOURCE', workspaceName), 'VNETID', '${split(globalFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'globalFeedPrivateEndpointName'
var globalFeedPrivateEndpointNICName = avdPrivateLink ? replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'global'), 'RESOURCE', workspaceName), 'VNETID', '${split(globalFeedPrivateEndpointSubnetResourceId, '/')[8]}') : 'globalFeedPrivateEndpointName'
var hostPoolPrivateEndpointName = avdPrivateLink ? replace(replace(replace(privateEndpointNameConv, 'SUBRESOURCE', 'connection'), 'RESOURCE', hostPoolName), 'VNETID', '${split(hostPoolPrivateEndpointSubnetResourceId, '/')[8]}') : 'hostPoolPrivateEndpointName'
var hostPoolPrivateEndpointNICName = avdPrivateLink ? replace(replace(replace(privateEndpointNICNameConv, 'SUBRESOURCE', 'connection'), 'RESOURCE', hostPoolName), 'VNETID', '${split(hostPoolPrivateEndpointSubnetResourceId, '/')[8]}') : 'hostPoolPrivateEndpointName'


module hostPool 'hostPool.bicep' = {
  name: 'HostPool_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    identitySolution: identitySolution
    avdPrivateLink: avdPrivateLink
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
    virtualMachineTemplate: virtualMachineTemplate
  }
}

module applicationGroup 'applicationGroup.bicep' = {
  name: 'ApplicationGroup_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    desktopApplicationGroupName: desktopApplicationGroupName
    hostPoolResourceId: hostPool.outputs.ResourceId
    location: locationControlPlane
    roleDefinitions: roleDefinitions
    securityPrincipalObjectIds: securityPrincipalObjectIds
    tags: tags 
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    desktopFriendlyName: desktopFriendlyName
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    managementVirtualMachineName: managementVirtualMachineName
    resourceGroupManagement: resourceGroupManagement
    timeStamp: timeStamp
  }
}

module feedWorkspace 'workspace.bicep' = {
  name: 'WorkspaceFeed_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    applicationGroupReferences: applicationGroup.outputs.ApplicationGroupReference
    avdPrivateLink: avdPrivateLink
    existingWorkspace: existingWorkspace
    friendlyName: workspaceFriendlyName
    location: locationControlPlane
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    enableMonitoring: enableMonitoring
    privateDnsZoneResourceId: avdPrivateDnsZoneResourceId
    privateEndpointName: feedPrivateEndpointName
    privateEndpointNICName: feedPrivateEndpointNICName
    privateEndpointSubnetResourceId: feedPrivateEndpointSubnetResourceId
    publicNetworkAccess: workspacePublicNetworkAccess
    tags: tags
    workspaceName: workspaceName
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    locationVirtualMachines: locationVirtualMachines
    managementVirtualMachineName: managementVirtualMachineName
    resourceGroupManagement: resourceGroupManagement
    timeStamp: timeStamp
  }
}

module scalingPlan 'scalingPlan.bicep' = if(deployScalingPlan && contains(hostPoolType,'Pooled')) {
  name: 'ScalingPlan_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    diagnosticWorkspaceId: logAnalyticsWorkspaceResourceId
    exclusionTag: scalingPlanExclusionTag
    hostPoolResourceId: hostPool.outputs.ResourceId
    hostPoolType: split(hostPoolType, ' ')[0]
    location: locationVirtualMachines
    name: scalingPlanName
    tags: tags
    schedules: scalingPlanSchedules
    timeZone: virtualMachinesTimeZone
  }
} 

module globalWorkspace 'workspace.bicep' = if(!existingGlobalWorkspace && avdPrivateLink && !empty(avdGlobalFeedPrivateDnsZoneResourceId)) {
  name: 'Global_Feed_Workspace_${timeStamp}'
  scope: resourceGroup(resourceGroupGlobalFeed)
  params: {
    applicationGroupReferences: []
    avdPrivateLink: avdPrivateLink
    existingWorkspace: existingGlobalWorkspace
    friendlyName: ''
    location: locationGlobalFeed
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    enableMonitoring: enableMonitoring
    privateDnsZoneResourceId: avdGlobalFeedPrivateDnsZoneResourceId
    privateEndpointName: globalFeedPrivateEndpointName
    privateEndpointNICName: globalFeedPrivateEndpointNICName
    privateEndpointSubnetResourceId: globalFeedPrivateEndpointSubnetResourceId
    tags: tags
    workspaceName: globalWorkspaceName
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    locationVirtualMachines: locationVirtualMachines
    managementVirtualMachineName: managementVirtualMachineName
    resourceGroupManagement: resourceGroupManagement
    timeStamp: timeStamp
  }
  dependsOn: [
    feedWorkspace
  ]
}

output hostPoolName string = last(split(hostPool.outputs.ResourceId, '/'))
