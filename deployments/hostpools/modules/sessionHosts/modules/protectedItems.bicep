param policyName string
param recoveryServicesVaultName string
param sessionHostCount int
param sessionHostIndex int
param virtualMachineNamePrefix string

var v2VmContainer = 'IaasVMContainer;iaasvmcontainerv2;'
var v2Vm = 'vm;iaasvmcontainerv2;'

resource rsv 'Microsoft.recoveryServices/vaults@2023-01-01' existing = {
  name: recoveryServicesVaultName
  resource backupPolicy 'backupPolicies@2024-10-01' existing = {
    name: policyName
  }
} 

resource protectedItems_Vm 'Microsoft.recoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-10-01' = [for i in range(0, sessionHostCount): {
  name: '${recoveryServicesVaultName}/Azure/${v2VmContainer}${resourceGroup().name};${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}/${v2Vm}${resourceGroup().name};${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: rsv::backupPolicy.id
    sourceResourceId: resourceId(resourceGroup().name, 'Microsoft.Compute/virtualMachines', '${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}')
  }
}]
