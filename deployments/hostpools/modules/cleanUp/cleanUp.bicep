targetScope = 'subscription' 

param deleteManagementResourceGroup bool
param location string
param resourceGroupHosts string
param resourceGroupManagement string
param timeStamp string
param userAssignedIdentityClientId string
param managementVirtualMachineName string
param roleAssignmentIds array
param virtualMachineNames array

module removeRunCommands 'modules/removeRunCommands.bicep' = {
  scope: resourceGroup(resourceGroupManagement)
  name: 'RemoveRunCommands_${timeStamp}'
  params: {
    location: location
    managementVmName: managementVirtualMachineName
    timeStamp: timeStamp
    userAssignedIdentityClientId: userAssignedIdentityClientId
    virtualMachineNames: virtualMachineNames
    virtualMachinesResourceGroup: resourceGroupHosts
  }
}


// Remove role assignments for the user Assigned Identity for resource groups other than the management resource group to allow the deletion of the user assigned identity in certain scenarios.
module removeRoleAssignments 'modules/removeRoleAssignments.bicep' = {
  scope: resourceGroup(resourceGroupManagement)
  name: 'Remove-Role-Assignments_${timeStamp}'
  params: {
    location: location
    managementVmName: managementVirtualMachineName
    roleAssignmentIds: filter(roleAssignmentIds, roleAssignmentId => split(roleAssignmentId, '/')[4] != resourceGroupManagement)
    timeStamp: timeStamp
    userAssignedIdentityClientId: userAssignedIdentityClientId
  }
  dependsOn: [
    removeRunCommands
  ]
}

module removeManagementVirtualMachine 'modules/removeVirtualMachine.bicep' = if(!deleteManagementResourceGroup) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'Remove-Management-VirtualMachine_${timeStamp}'
  params: {
    location: location
    managementVmName: managementVirtualMachineName
    timeStamp: timeStamp
    userAssignedIdentityClientId: userAssignedIdentityClientId
  }
  dependsOn: [
    removeRunCommands
    removeRoleAssignments
  ]
}

module removeManagementResourceGroup 'modules/removeManagementResourceGroup.bicep' = if(deleteManagementResourceGroup) {
  scope: resourceGroup(resourceGroupManagement)
  name: 'Remove-Management-ResourceGroup_${timeStamp}'
  params: {
    location: location
    managementVmName: managementVirtualMachineName
    timeStamp: timeStamp
    userAssignedIdentityClientId: userAssignedIdentityClientId
  }
  dependsOn: [
    removeRunCommands
    removeRoleAssignments
  ]
}

