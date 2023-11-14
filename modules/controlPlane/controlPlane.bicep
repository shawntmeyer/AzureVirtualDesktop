targetScope = 'subscription'

param ActiveDirectorySolution string
param CustomRdpProperty string
param DesktopApplicationGroupName string
param DesktopFriendlyName string
param HostPoolName string
param HostPoolType string
param Location string
param LogAnalyticsWorkspaceResourceId string
param ManagementVmName string
param MaxSessionLimit int
param Monitoring bool
param ResourceGroupControlPlane string
param ResourceGroupManagement string
param RoleDefinitions object
param SecurityPrincipalObjectIds array
param TagsApplicationGroup object
param TagsHostPool object
param Timestamp string
param UserAssignedIdentityClientId string
param ValidationEnvironment bool
param VmTemplate string
param WorkspaceFriendlyName string
param WorkspaceName string

module hostPool 'hostPool.bicep' = {
  name: 'HostPool_${Timestamp}'
  scope: resourceGroup(ResourceGroupControlPlane)
  params: {
    ActiveDirectorySolution: ActiveDirectorySolution
    CustomRdpProperty: CustomRdpProperty
    HostPoolName: HostPoolName
    HostPoolType: HostPoolType
    Location: Location
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    MaxSessionLimit: MaxSessionLimit
    Monitoring: Monitoring
    TagsHostPool: TagsHostPool
    ValidationEnvironment: ValidationEnvironment
    VmTemplate: VmTemplate
  }
}

module applicationGroup 'applicationGroup.bicep' = {
  name: 'ApplicationGroup_${Timestamp}'
  scope: resourceGroup(ResourceGroupControlPlane)
  params: {
    DesktopApplicationGroupName: DesktopApplicationGroupName
    HostPoolResourceId: hostPool.outputs.ResourceId
    Location: Location
    RoleDefinitions: RoleDefinitions
    SecurityPrincipalObjectIds: SecurityPrincipalObjectIds
    TagsApplicationGroup: TagsApplicationGroup
  }
}

module updateDesktopFriendlyName 'updateDesktopFriendlyName.bicep' = if (!empty(DesktopFriendlyName)) {
  scope: resourceGroup(ResourceGroupManagement)
  name: 'Update_Desktop_Friendly_Name_${Timestamp}'
  params: {
    DesktopAppGroupName: last(split(applicationGroup.outputs.ResourceId, '/'))
    DesktopAppGroupResourceGroup: split(applicationGroup.outputs.ResourceId, '/')[4]
    DesktopFriendlyName: DesktopFriendlyName
    Location: Location
    ManagementVmName: ManagementVmName
    UserAssignedIdentityClientId: UserAssignedIdentityClientId
  }
}

module existingWorkspace '../management/workspace.bicep' = {
  name: 'Workspace_Existing_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    ApplicationGroupReferences: []
    Existing: true
    FriendlyName: WorkspaceFriendlyName
    Location: Location
    Timestamp: Timestamp
    WorkspaceName: WorkspaceName
  }
}

module updateWorkspace '../management/workspace.bicep' = {
  name: 'Workspace_Update_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    ApplicationGroupReferences: union(existingWorkspace.outputs.applicationGroupReferences, applicationGroup.outputs.ApplicationGroupReference)
    Existing: false
    FriendlyName: WorkspaceFriendlyName
    Location: Location
    Tags: existingWorkspace.outputs.tags
    Timestamp: Timestamp
    WorkspaceName: WorkspaceName
  }
}
