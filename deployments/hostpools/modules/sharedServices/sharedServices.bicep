targetScope = 'subscription'

param globalWorkspacePrivateDnsZoneResourceId string
param resourceGroupName string
param sharedServicesSubnetResourceId string
param timeStamp string
param workspaceNamePrefix string

module virtualNetwork 'virtualNetwork.bicep' = {
  scope: resourceGroup(split(sharedServicesSubnetResourceId, '/')[4])
  name: 'SharedServices_VirtualNetwork_${timeStamp}'
  params: {
    name: split(sharedServicesSubnetResourceId, '/')[8]
  }
}

// Resource Group for the global AVD Workspace
module rg_GlobalWorkspace '../resourceGroup.bicep' = {
  name: 'ResourceGroup_WorkspaceGlobal_${timeStamp}'
  scope: subscription(split(sharedServicesSubnetResourceId, '/')[2])
  params: {
    location: virtualNetwork.outputs.location
    resourceGroupName: resourceGroupName
    tags: {}
  }
}

module workspace 'workspace.bicep' = {
  name: 'WorkspaceGlobal_${timeStamp}'
  scope: resourceGroup(resourceGroupName)
  params: {
    globalWorkspacePrivateDnsZoneResourceId: globalWorkspacePrivateDnsZoneResourceId
    location: virtualNetwork.outputs.location
    subnetResourceId: sharedServicesSubnetResourceId
    workspaceNamePrefix: workspaceNamePrefix
  }
  dependsOn: [
    rg_GlobalWorkspace
  ]
}
