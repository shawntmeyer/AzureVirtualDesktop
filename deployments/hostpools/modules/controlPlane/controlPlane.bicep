targetScope = 'subscription'

param activeDirectorySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param avdGlobalFeedPrivateDnsZoneResourceId string
param avdPrivateDnsZoneResourceId string
param avdPrivateLink bool
param hostPoolRDPProperties string
param deploymentUserAssignedIdentityClientId string
param desktopApplicationGroupName string
param desktopFriendlyName string
param existingGlobalWorkspace bool
param existingWorkspace bool
param globalWorkspaceName string
param globalWorkspacePublicNetworkAccess string
param hostPoolName string
param hostPoolType string
param locationControlPlane string
param locationVirtualMachines string
param logAnalyticsWorkspaceResourceId string
param managementVirtualMachineName string
param hostPoolMaxSessionLimit int
param hostPoolPublicNetworkAccess string
param monitoring bool
param privateEndpointNameConv string
param privateEndpointSubnetResourceId string
param resourceGroupControlPlane string
param resourceGroupGlobalFeed string
param resourceGroupManagement string
param roleDefinitions object
param securityPrincipalObjectIds array
param tags object
param timeStamp string
param hostPoolValidationEnvironment bool
param virtualMachineTemplate string
param workspaceFriendlyName string
param workspaceName string
param workspacePublicNetworkAccess string

var feedPrivateEndpointName = replace(replace(privateEndpointNameConv, 'subresource', 'feed'), 'resource', workspaceName)
var globalFeedPrivateEndpointName = replace(replace(privateEndpointNameConv, 'subresource', 'global'), 'resource', workspaceName)
var hostPoolPrivateEndpointName = replace(replace(privateEndpointNameConv, 'subresource', 'connection'), 'resource', hostPoolName)

module hostPool 'hostPool.bicep' = {
  name: 'HostPool_${timeStamp}'
  scope: resourceGroup(resourceGroupControlPlane)
  params: {
    activeDirectorySolution: activeDirectorySolution
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
    monitoring: monitoring    
    privateEndpointName: hostPoolPrivateEndpointName
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
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
    monitoring: monitoring
    privateDnsZoneResourceId: avdPrivateDnsZoneResourceId
    privateEndpointName: feedPrivateEndpointName
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
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

module globalWorkspace 'workspace.bicep' = if(!existingGlobalWorkspace && avdPrivateLink && !empty(avdGlobalFeedPrivateDnsZoneResourceId)) {
  name: 'Global_Feed_Workspace_${timeStamp}'
  scope: resourceGroup(resourceGroupGlobalFeed)
  params: {
    applicationGroupReferences: ['']
    avdPrivateLink: avdPrivateLink
    existingWorkspace: existingGlobalWorkspace
    friendlyName: ''
    location: locationControlPlane
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    monitoring: monitoring
    privateDnsZoneResourceId: avdGlobalFeedPrivateDnsZoneResourceId
    privateEndpointName: globalFeedPrivateEndpointName
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    publicNetworkAccess: globalWorkspacePublicNetworkAccess
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
