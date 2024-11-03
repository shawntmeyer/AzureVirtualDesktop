targetScope = 'subscription' 

param location string
param resourceGroupHosts string
param resourceGroupDeployment string
param timeStamp string
param userAssignedIdentityClientId string
param deploymentVirtualMachineName string
param roleAssignmentIds array
param virtualMachineNames array

module removeRunCommands 'modules/removeRunCommands.bicep' = {
  scope: resourceGroup(resourceGroupDeployment)
  name: 'Remove_RunCommands_${timeStamp}'
  params: {
    location: location
    deploymentVmName: deploymentVirtualMachineName
    timeStamp: timeStamp
    userAssignedIdentityClientId: userAssignedIdentityClientId
    virtualMachineNames: virtualMachineNames
    virtualMachinesResourceGroup: resourceGroupHosts
  }
}


// Remove role assignments for the user Assigned Identity for resource groups other than the deployment resource group to allow the deletion of the resource group.
module removeRoleAssignments 'modules/removeRoleAssignments.bicep' = {
  scope: resourceGroup(resourceGroupDeployment)
  name: 'Remove_RoleAssignments_${timeStamp}'
  params: {
    location: location
    managementVmName: deploymentVirtualMachineName
    roleAssignmentIds: filter(roleAssignmentIds, roleAssignmentId => split(roleAssignmentId, '/')[4] != resourceGroupDeployment)
    timeStamp: timeStamp
    userAssignedIdentityClientId: userAssignedIdentityClientId
  }
  dependsOn: [
    removeRunCommands
  ]
}

module removeDeploymentResourceGroup 'modules/removeDeploymentResourceGroup.bicep' = {
  scope: resourceGroup(resourceGroupDeployment)
  name: 'Delete_DeploymentResourceGroup_${timeStamp}'
  params: {
    location: location
    deploymentVmName: deploymentVirtualMachineName
    timeStamp: timeStamp
    userAssignedIdentityClientId: userAssignedIdentityClientId
  }
  dependsOn: [
    removeRunCommands
    removeRoleAssignments
  ]
}

