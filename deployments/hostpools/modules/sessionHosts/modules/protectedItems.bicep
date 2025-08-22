param location string
param PolicyId string
param recoveryServicesVaultName string
param sessionHostCount int
param sessionHostIndex int
param tags object
param virtualMachineNamePrefix string
param VirtualMachineResourceGroupName string

var v2VmContainer = 'iaasvmcontainer;iaasvmcontainerv2;'
var v2Vm = 'vm;iaasvmcontainerv2;'

resource protectedItems_Vm 'Microsoft.recoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2021-08-01' = [for i in range(0, sessionHostCount): {
  name: '${recoveryServicesVaultName}/Azure/${v2VmContainer}${VirtualMachineResourceGroupName};${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}/${v2Vm}${VirtualMachineResourceGroupName};${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
  location: location
  tags: tags
  properties: {
    protectedItemType: 'Microsoft.ClassicCompute/virtualMachines'
    policyId: PolicyId
    sourceResourceId: resourceId(VirtualMachineResourceGroupName, 'Microsoft.Compute/virtualMachines', '${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}')
  }
}]
