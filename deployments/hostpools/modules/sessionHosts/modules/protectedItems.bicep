param backupPolicyId string
param recoveryServicesVaultName string
param sessionHostCount int
param sessionHostIndex int
param virtualMachineNamePrefix string

var v2VmContainer = 'iaasvmcontainer;iaasvmcontainerv2;'
var v2Vm = 'vm;iaasvmcontainerv2;'

resource protectedItems_Vm 'Microsoft.recoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2021-08-01' = [for i in range(0, sessionHostCount): {
  name: '${recoveryServicesVaultName}/Azure/${v2VmContainer}${resourceGroup().name};${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}/${v2Vm}${resourceGroup().name};${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: backupPolicyId
    sourceResourceId: resourceId(resourceGroup().name, 'Microsoft.Compute/virtualMachines', '${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}')
  }
}]
