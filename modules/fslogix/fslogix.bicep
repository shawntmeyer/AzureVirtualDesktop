targetScope = 'subscription'

param ActiveDirectoryConnection string
param ActiveDirectorySolution string
param ArtifactsLocation string
param ArtifactsUserAssignedIdentityClientId string
param AutomationAccountName string
param Availability string
param AzureFilesPrivateDnsZoneResourceId string
param AzureFilesUserAssignedIdentityClientId string
param DelegatedSubnetId string
param DnsServers string
@secure()
param DomainJoinPassword string
param DomainJoinUserPrincipalName string
param DomainName string
param FileShares array
param FslogixShareSizeInGB int
param FslogixSolution string
param FslogixStorage string
param KerberosEncryption string
param Location string
param ManagementVmName string
param NetAppAccountName string
param NetAppCapacityPoolName string
param Netbios string
param OuPath string
param PrivateEndpoint bool
param RecoveryServices bool
param RecoveryServicesVaultName string
param ResourceGroupManagement string
param ResourceGroupStorage string
param SecurityPrincipalObjectIds array
param SecurityPrincipalNames array
param SmbServerLocation string
param StorageAccountNamePrefix string
param StorageCount int
param StorageIndex int
param StorageSku string
param StorageSolution string
param Subnet string
param TagsAutomationAccounts object
param TagsNetAppAccount object
param TagsPrivateEndpoints object
param TagsRecoveryServicesVault object
param TagsStorageAccounts object
param TagsVirtualMachines object
param Timestamp string
param TimeZone string
param VirtualNetwork string
param VirtualNetworkResourceGroup string

// Azure NetApp Files for Fslogix
module azureNetAppFiles 'azureNetAppFiles.bicep' = if (StorageSolution == 'AzureNetAppFiles' && contains(ActiveDirectorySolution, 'DomainServices')) {
  name: 'AzureNetAppFiles_${Timestamp}'
  scope: resourceGroup(ResourceGroupStorage)
  params: {
    ActiveDirectoryConnection: ActiveDirectoryConnection
    ArtifactsLocation: ArtifactsLocation
    ArtifactsUserAssignedIdentityClientId: ArtifactsUserAssignedIdentityClientId
    DelegatedSubnetId: DelegatedSubnetId
    DnsServers: DnsServers
    DomainJoinPassword: DomainJoinPassword
    DomainJoinUserPrincipalName: DomainJoinUserPrincipalName
    DomainName: DomainName
    FileShares: FileShares
    FslogixSolution: FslogixSolution
    Location: Location
    ManagementVmName: ManagementVmName
    NetAppAccountName: NetAppAccountName
    NetAppCapacityPoolName: NetAppCapacityPoolName
    OuPath: OuPath
    ResourceGroupManagement: ResourceGroupManagement
    SecurityPrincipalNames: SecurityPrincipalNames
    SmbServerLocation: SmbServerLocation
    StorageSku: StorageSku
    StorageSolution: StorageSolution
    TagsNetAppAccount: TagsNetAppAccount
    TagsVirtualMachines: TagsVirtualMachines
    Timestamp: Timestamp
  }
}

// Azure Files for FSLogix
module azureFiles 'azureFiles/azureFiles.bicep' = if (StorageSolution == 'AzureFiles') {
  name: 'AzureFiles_${Timestamp}'
  scope: resourceGroup(ResourceGroupStorage)
  params: {
    ActiveDirectorySolution: ActiveDirectorySolution
    ArtifactsLocation: ArtifactsLocation
    ArtifactsUserAssignedIdentityClientId: ArtifactsUserAssignedIdentityClientId
    AutomationAccountName: AutomationAccountName
    Availability: Availability
    AzureFilesPrivateDnsZoneResourceId: AzureFilesPrivateDnsZoneResourceId
    AzureFilesUserAssignedIdentityClientId: AzureFilesUserAssignedIdentityClientId
    DomainJoinPassword: DomainJoinPassword
    DomainJoinUserPrincipalName: DomainJoinUserPrincipalName
    FileShares: FileShares
    FslogixShareSizeInGB: FslogixShareSizeInGB
    FslogixSolution: FslogixSolution
    FslogixStorage: FslogixStorage
    KerberosEncryption: KerberosEncryption
    Location: Location
    ManagementVmName: ManagementVmName
    Netbios: Netbios
    OuPath: OuPath
    PrivateEndpoint: PrivateEndpoint
    RecoveryServices: RecoveryServices
    RecoveryServicesVaultName: RecoveryServicesVaultName
    ResourceGroupManagement: ResourceGroupManagement
    ResourceGroupStorage: ResourceGroupStorage
    SecurityPrincipalObjectIds: SecurityPrincipalObjectIds
    SecurityPrincipalNames: SecurityPrincipalNames
    StorageAccountNamePrefix: StorageAccountNamePrefix
    StorageCount: StorageCount
    StorageIndex: StorageIndex
    StorageSku: StorageSku
    StorageSolution: StorageSolution
    Subnet: Subnet
    TagsAutomationAccounts: TagsAutomationAccounts
    TagsPrivateEndpoints: TagsPrivateEndpoints
    TagsRecoveryServicesVault: TagsRecoveryServicesVault
    TagsStorageAccounts: TagsStorageAccounts
    TagsVirtualMachines: TagsVirtualMachines
    Timestamp: Timestamp
    TimeZone: TimeZone
    VirtualNetwork: VirtualNetwork
    VirtualNetworkResourceGroup: VirtualNetworkResourceGroup
  }
}

output netAppShares array = StorageSolution == 'AzureNetAppFiles' ? azureNetAppFiles.outputs.fileShares : [
  'None'
]
