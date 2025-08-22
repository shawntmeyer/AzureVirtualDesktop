param policyName string
param recoveryServicesVaultName string
param sessionHostCount int
param sessionHostIndex int
param virtualMachineNamePrefix string

resource vault 'Microsoft.RecoveryServices/vaults@2021-08-01' existing = {
  name: recoveryServicesVaultName
}

resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2021-08-01' existing = {
  name: policyName
  parent: vault
}

resource vms 'Microsoft.Compute/virtualMachines@2022-08-01' existing = [for i in range(0, sessionHostCount): {
  name: '${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
}]

resource backupProtectionContainers 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2024-04-01' = [for i in range(0, sessionHostCount): {
  name: '${recoveryServicesVaultName}/Azure/IaasVMContainer;iaasvmcontainerv2;${resourceGroup().name};${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
}]

resource backupProtectedItems 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-04-01' = [for i in range(0, sessionHostCount): {
  name: 'vm;iaasvmcontainerv2;${resourceGroup().name};${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
  parent: backupProtectionContainers[i]
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: backupPolicy.id
    sourceResourceId: vms[i].id
  }
}]
