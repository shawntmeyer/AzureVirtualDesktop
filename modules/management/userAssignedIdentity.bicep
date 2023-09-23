param ArtifactsStorageAccountResourceId string
param ArtifactsUserAssignedIdentityResourceId string
param DiskEncryption bool
param DrainMode bool
param Fslogix bool
param FslogixStorage string
param Location string
param ResourceGroupControlPlane string
param ResourceGroupStorage string
param Tags object
param Timestamp string
param UserAssignedIdentityName string
param VirtualNetworkResourceGroupName string

var ArtifactsStorageRoleAssignment = !empty(ArtifactsStorageAccountResourceId) && empty(ArtifactsUserAssignedIdentityResourceId) ? [
  {
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
    scope: '${split(ArtifactsStorageAccountResourceId, '/')[2]}, ${split(ArtifactsStorageAccountResourceId, '/')[4]}'
  }
] : []
var DiskEncryptionRoleAssignment = DiskEncryption ? [
  {
    roleDefinitionId: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603' // Key Vault Crypto Officer (Purpose: create customer managed key)
    scope: resourceGroup().name
  }
] : []
var DrainModeRoleAssignment = DrainMode ? [
  {
    roleDefinitionId: '2ad6aaab-ead9-4eaa-8ac5-da422f562408' // Desktop Virtualization Session Host Operator (Purpose: put session hosts in drain mode)
    scope: ResourceGroupControlPlane
  }
] : []
var FSLogixNtfsRoleAssignments = Fslogix ? [
  {
    roleDefinitionId: '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor (Purpose: domain join storage account & set NTFS permissions on the file share)
    scope: ResourceGroupStorage
  }
] : []
var RemoveManagementVirtualMachine = [
  {
    roleDefinitionId: 'a959dbd1-f747-45e3-8ba6-dd80f235f97c' // Desktop Virtualization Virtual Machine Contributor (Purpose: remove the management virtual machine)
    scope: resourceGroup().name
  }
]
var FSLogixPrivateEndpointRoleAssignment = contains(FslogixStorage, 'PrivateEndpoint') ? [
  {
    roleDefinitionId: '4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor (Purpose: configure DNS resolution for private endpoints)
    scope: VirtualNetworkResourceGroupName
  }
] : []
var FSLogixRoleAssignments = union(FSLogixNtfsRoleAssignments, FSLogixPrivateEndpointRoleAssignment)
var RoleAssignments = union(ArtifactsStorageRoleAssignment, DiskEncryptionRoleAssignment, DrainModeRoleAssignment, FSLogixRoleAssignments, RemoveManagementVirtualMachine)

resource artifactsUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if(!empty(ArtifactsUserAssignedIdentityResourceId)) {
  name: last(split(ArtifactsUserAssignedIdentityResourceId, '/'))
  scope: resourceGroup(split(ArtifactsUserAssignedIdentityResourceId, '/')[2], split(ArtifactsUserAssignedIdentityResourceId, '/')[4])
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: UserAssignedIdentityName
  location: Location
  tags: Tags
}

module roleAssignments '../roleAssignment.bicep' = [for i in range(0, length(RoleAssignments)): {
  name: 'UAI_RoleAssignment_${i}_${Timestamp}'
  scope: resourceGroup(RoleAssignments[i].scope)
  params: {
    PrincipalId: userAssignedIdentity.properties.principalId
    PrincipalType: 'ServicePrincipal'
    RoleDefinitionId: RoleAssignments[i].roleDefinitionId
  }
}]

output ArtifactsUserAssignedIdentityClientId string = !empty(ArtifactsUserAssignedIdentityResourceId) ? artifactsUserAssignedIdentity.properties.clientId : userAssignedIdentity.properties.clientId
output clientId string = userAssignedIdentity.properties.clientId
output id string = userAssignedIdentity.id
output principalId string = userAssignedIdentity.properties.principalId
