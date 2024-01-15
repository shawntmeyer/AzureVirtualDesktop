targetScope = 'subscription' 

param location string
param resourceGroupManagement string
param timeStamp string
param userAssignedIdentityClientId string
param virtualMachineName string

module removeManagementVirtualMachine 'removeVirtualMachine.bicep' = {
  scope: resourceGroup(resourceGroupManagement)
  name: 'RemoveManagementVirtualMachine_${timeStamp}'
  params: {
    location: location
    userAssignedIdentityClientId: userAssignedIdentityClientId
    virtualMachineName: virtualMachineName
  }
}
