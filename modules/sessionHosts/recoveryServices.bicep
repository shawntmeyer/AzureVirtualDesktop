param DivisionRemainderValue int
param FslogixDeployed bool
param Location string
param MaxResourcesPerTemplateDeployment int
param RecoveryServicesVaultName string
param ResourceGroupHosts string
param ResourceGroupManagement string
param SessionHostBatchCount int
param SessionHostIndex int
param TagsRecoveryServicesVault object
param Timestamp string
param VirtualMachineNamePrefix string

resource vault 'Microsoft.RecoveryServices/vaults@2022-03-01' existing = {
  name: RecoveryServicesVaultName
  scope: resourceGroup(ResourceGroupManagement)
}

resource backupPolicy_Vm 'Microsoft.RecoveryServices/vaults/backupPolicies@2022-03-01' existing = {
  parent: vault
  name: 'AvdPolicyVm'
}

module protectedItems_Vm 'protectedItems.bicep' = [for i in range(1, SessionHostBatchCount): if (!FslogixDeployed) {
  name: 'BackupProtectedItems_VirtualMachines_${i - 1}_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement) // Management Resource Group
  params: {
    Location: Location
    PolicyId: backupPolicy_Vm.id
    RecoveryServicesVaultName: vault.name
    SessionHostCount: i == SessionHostBatchCount && DivisionRemainderValue > 0 ? DivisionRemainderValue : MaxResourcesPerTemplateDeployment
    SessionHostIndex: i == 1 ? SessionHostIndex : ((i - 1) * MaxResourcesPerTemplateDeployment) + SessionHostIndex
    Tags: TagsRecoveryServicesVault
    VirtualMachineNamePrefix: VirtualMachineNamePrefix
    VirtualMachineResourceGroupName: ResourceGroupHosts
  }

}]
