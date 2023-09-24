targetScope = 'subscription'

@description('''Required.
The URL prefix for the scripts required in this solution.
If you do not have public internet access to the default value below, you need to host the scripts in the "artifacts" folder in Azure Blobs and provide the URL prefix below.
''')
param ArtifactsLocation string

@description('Optional. The storage account resource Id where the artifacts used by this deployment are stored.')
param ArtifactsStorageAccountResourceId string = ''

@description('''Optional.
The resource ID of the managed identity with Storage Blob Data Reader Access to the artifacts storage Account.
If provided this identity will be used to access blobs. Otherwise, the managed identity created
by this solution will be granted \'Storage Blob Data Reader\' rights on the storage account.
''')
param ArtifactsUserAssignedIdentityResourceId string = ''

@allowed([
  'ActiveDirectoryDomainServices' // User accounts are sourced from and Session Hosts are joined to same Active Directory domain.
  'AzureActiveDirectoryDomainServices' // User accounts are sourced from either Azure Active Directory or Active Directory Domain Services and Session Hosts are joined to Azure Active Directory Domain Services.
  'AzureActiveDirectory' // User accounts and Session Hosts are located in Azure Active Directory Only (Cloud Only Scenario)
  'AzureActiveDirectoryIntuneEnrollment' // User accounts and Session Hosts are located in Azure Active Directory Only. Session Hosts are automatically enrolled in Intune. (Cloud Only Scenario)
  'AzureActiveDirectoryAndKerberos' // User accounts are sourced from Active Directory domain and session hosts are joined to Azure Active Directory natively.
  'AzureActiveDirectoryAndKerberosIntuneEnrollment' // User accounts are sourced from Active Directory domain and session hosts are joined to Azure Active Directory natively with Intune Enrollment.
])
@description('The service providing domain services for Azure Virtual Desktop.  This is needed to properly configure the session hosts and if applicable, the Azure Storage Account.')
param ActiveDirectorySolution string

@allowed([
  'AvailabilitySets'
  'AvailabilityZones'
  'None'
])
@description('Set the desired availability / SLA with a pooled host pool.  The best practice is to deploy to Availability Zones for resilency.')
param Availability string = 'AvailabilityZones'

@description('The Object ID for the Windows Virtual Desktop Enterprise Application in Azure AD.  The Object ID can found by selecting Microsoft Applications using the Application type filter in the Enterprise Applications blade of Azure AD.')
param AvdObjectId string

@description('If using private endpoints with Azure Files, input the Resource ID for the Private DNS Zone linked to your hub virtual network.')
param AzureFilesPrivateDnsZoneResourceId string = ''

@description('''Array of script (or other artifact) names or full uris that will be downloaded by the Custom Script Extension on each Session Host Virtual Machine.
Either specify the entire URL or just the name of the blob if is located at the fqdn specified by the [ArtifactsLocation] parameter.
''')
param CSEFiles array = [
  'cse_master_script.ps1'
]

@description('''Additional Custom Dynamic Parameters passed to CSE Scripts.
(ex: 'Script2Keys=@([pscustomobject]@{stringValue=\'storageAccountName\';booleanValue=\'false\'});Script3Keys=@([pscustomobject]@{intValue=\'10\'}')
''')
param CSEScriptAddDynParameters string = ''

@description('''Optional. Input RDP properties to add or remove RDP functionality on the AVD host pool.
Settings reference: https://learn.microsoft.com/windows-server/remote/remote-desktop-services/clients/rdp-files
''')
param CustomRdpProperty string = 'audiocapturemode:i:1;camerastoredirect:s:*;use multimon:i:0;drivestoredirect:s:;'

@description('Enable Server-Side Encrytion and Encryption at Host on the AVD session hosts and management VM.')
param DiskEncryption bool = true

@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
@description('The storage SKU for the AVD session host disks.  Production deployments should use Premium_LRS.')
param DiskSku string = 'Premium_LRS'

@secure()
@description('The password of the privileged account to domain join the AVD session hosts to your domain')
param DomainJoinPassword string = ''

@description('The UPN of the privileged account to domain join the AVD session hosts to your domain. This should be an account the resides within the domain you are joining.')
param DomainJoinUserPrincipalName string = ''

@description('The name of the domain that provides ADDS to the AVD session hosts and is synchronized with Azure AD')
param DomainName string = ''

@description('Enable drain mode on new sessions hosts to prevent users from accessing them until they are validated.')
param DrainMode bool = false

@allowed([
  'd' // Development
  'p' // Production
  's' // Shared
  't' // Test
])
@description('The target environment for the solution.')
param Environment string = 'd'

@description('The file share size(s) in GB for the Fslogix storage solution.')
param FslogixShareSizeInGB int = 100

@allowed([
  'CloudCacheProfileContainer' // FSLogix Cloud Cache Profile Container
  'CloudCacheProfileOfficeContainer' // FSLogix Cloud Cache Profile & Office Container
  'ProfileContainer' // FSLogix Profile Container
  'ProfileOfficeContainer' // FSLogix Profile & Office Container
])
param FslogixSolution string = 'ProfileContainer'

@allowed([
  'AzureNetAppFiles Premium' // ANF with the Premium SKU, 450,000 IOPS
  'AzureNetAppFiles Standard' // ANF with the Standard SKU, 320,000 IOPS
  'AzureStorageAccount Premium PublicEndpoint' // Azure Files Premium with the default public endpoint, 100,000 IOPS
  'AzureStorageAccount Premium PrivateEndpoint' // Azure Files Premium with a Private Endpoint, 100,000 IOPS
  'AzureStorageAccount Premium ServiceEndpoint' // Azure Files Premium with a Service Endpoint, 100,000 IOPs
  'AzureStorageAccount Standard PublicEndpoint' // Azure Files Standard with the Large File Share option and the default public endpoint, 20,000 IOPS
  'AzureStorageAccount Standard PrivateEndpoint' // Azure Files Standard with the Large File Share option and a Private Endpoint, 20,000 IOPS
  'AzureStorageAccount Standard ServiceEndpoint' // Azure Files Standard with the Large File Share option and a Service Endpoint, 20,000 IOPS
  'None'
])
@description('Enable an Fslogix storage option to manage user profiles for the AVD session hosts. The selected service & SKU should provide sufficient IOPS for all of your users. https://docs.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix#performance-requirements')
param FslogixStorage string = 'AzureStorageAccount Standard PublicEndpoint'

@description('The Resource Id of the subnet on which to create the storage account private endpoint. Required when storage solution contains PrivateEndpoint.')
param PESubnetResourceId string = ''

@description('Configure FSLogix agent on the session hosts via local registry keys.')
param FslogixConfigureSessionHosts bool = true

@description('''Existing FSLogix Storage Account Resource Ids. Only used when FslogixConfigureSessionHosts = "true".
This list will be added to any storage accounts created when setting "FslogixStorage" to any of the AzureStorageAccount options. 
If "ActiveDirectorySolution" is set to "AzureActiveDirectory" or "AzureActiveDirectoryIntuneEnrollment" then only the first storage account listed will be used.
''')
param FslogixExistingStorageAccountResourceIds array = []

@allowed([
  'Pooled DepthFirst'
  'Pooled BreadthFirst'
  'Personal Automatic'
  'Personal Direct'
])
@description('These options specify the host pool type and depending on the type provides the load balancing options and assignment types.')
param HostPoolType string = 'Pooled DepthFirst'

@maxLength(3)
@description('The unique identifier between each business unit or project supporting AVD in your tenant. This is the unique naming component between each AVD stamp.')
param Identifier string = 'avd'

@description('Offer for the virtual machine image')
param ImageOffer string = 'office-365'

@description('Publisher for the virtual machine image')
param ImagePublisher string = 'MicrosoftWindowsDesktop'

@description('SKU for the virtual machine image')
param ImageSku string = 'win11-22h2-avd-m365'

@description('The resource ID for the Compute Gallery Image Version. Do not set this value if using a marketplace image.')
param ImageVersionResourceId string = ''

@allowed([
  'AES256'
  'RC4'
])
@description('The Active Directory computer object Kerberos encryption type for the Azure Storage Account or Azure NetApp Files Account.')
param KerberosEncryption string = 'RC4'

@description('The deployment location for the AVD management resources.')
param LocationControlPlane string = deployment().location

@maxValue(730)
@minValue(30)
@description('The retention for the Log Analytics Workspace to setup the AVD Monitoring solution')
param LogAnalyticsWorkspaceRetention int = 30

@allowed([
  'Free'
  'Standard'
  'Premium'
  'PerNode'
  'PerGB2018'
  'Standalone'
  'CapacityReservation'
])
@description('The SKU for the Log Analytics Workspace to setup the AVD Monitoring solution')
param LogAnalyticsWorkspaceSku string = 'PerGB2018'

@description('The maximum number of sessions per AVD session host.')
param MaxSessionLimit int

@description('Deploys the required monitoring resources to enable AVD Insights and monitor features in the automation account.')
param Monitoring bool = true

@description('The distinguished name for the target Organization Unit in Active Directory Domain Services.')
param OuPath string = ''

@description('Enable backups to an Azure Recovery Services vault.  For a pooled host pool this will enable backups on the Azure file share.  For a personal host pool this will enable backups on the AVD sessions hosts.')
param RecoveryServices bool = false

@description('Time when session hosts will scale up and continue to stay on to support peak demand; Format 24 hours e.g. 9:00 for 9am')
param ScalingBeginPeakTime string = '9:00'

@description('Time when session hosts will scale down and stay off to support low demand; Format 24 hours e.g. 17:00 for 5pm')
param ScalingEndPeakTime string = '17:00'

@description('The number of seconds to wait before automatically signing out users. If set to 0 any session host that has user sessions will be left untouched')
param ScalingLimitSecondsToForceLogOffUser string = '0'

@description('The minimum number of session host VMs to keep running during off-peak hours. The scaling tool will not work if all virtual machines are turned off and the Start VM On Connect solution is not enabled.')
param ScalingMinimumNumberOfRdsh string = '0'

@description('The maximum number of sessions per CPU that will be used as a threshold to determine when new session host VMs need to be started during peak hours')
param ScalingSessionThresholdPerCPU string = '1'

@description('Deploys the required resources for the Scaling Tool. https://docs.microsoft.com/en-us/azure/virtual-desktop/scaling-automation-logic-apps')
param ScalingTool bool = true

@description('The resource ID of the log analytics workspace used for Azure Sentinel and / or Defender for Cloud. When using the Microsoft Monitoring Agent, this allows you to multihome the agent to reduce unnecessary log collection and reduce cost.')
param SecurityLogAnalyticsWorkspaceResourceId string = ''

@description('An array of Security Principals with their object IDs and display names to assign to the AVD Application Group and FSLogix Storage.')
param SecurityPrincipals array = []

@maxValue(5000)
@minValue(0)
@description('The number of session hosts to deploy in the host pool. Ensure you have the approved quota to deploy the desired count.')
param SessionHostCount int = 1

@maxValue(4999)
@minValue(0)
@description('The starting number for the session hosts. This is important when adding virtual machines to ensure an update deployment is not performed on an exiting, active session host.')
param SessionHostIndex int = 0

@maxValue(9)
@minValue(0)
@description('The stamp index allows for multiple AVD stamps with the same business unit or project to support different use cases. For example, "0" could be used for an office workers host pool and "1" could be used for a developers host pool within the "finance" business unit.')
param StampIndex int = 0

@maxValue(100)
@minValue(0)
@description('''
The number of storage accounts to deploy to support the required use case for the AVD stamp. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding
Note: Cannot utilize sharding with "ActiveDirectorySolution" = "AAD" so StorageCount will be set to 1 in variables.
''')
param StorageCount int = 1

@maxValue(99)
@minValue(0)
@description('The starting number for the storage accounts to support the required use case for the AVD stamp. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding')
param StorageIndex int = 0

@description('The resource ID of the subnet to place the network interfaces for the AVD session hosts.')
param VMSubnetResourceId string

@description('Key / value pairs of metadata for the Azure resource groups and resources.')
param Tags object = {}

@description('DO NOT MODIFY THIS VALUE! The timestamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param Timestamp string = utcNow('yyyyMMddhhmmss')

@description('The value determines whether the hostpool should receive early AVD updates for testing.')
param ValidationEnvironment bool = false

/* @allowed([
  'AzureMonitorAgent'
  'LogAnalyticsAgent'
])
@description('Input the desired monitoring agent to send events and performance counters to a log analytics workspace.')
param VirtualMachineMonitoringAgent string = 'LogAnalyticsAgent' */

@secure()
@description('Local administrator password for the AVD session hosts')
param VirtualMachinePassword string

@description('The VM SKU for the AVD session hosts.')
param VirtualMachineSize string = 'Standard_D4ads_v5'

@description('The Local Administrator Username for the Session Hosts')
param VirtualMachineUsername string

@description('The friendly name for the AVD workspace that is displayed in the client.')
param WorkspaceFriendlyName string

// Existing Virtual Network Location
resource vmVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: split(VMSubnetResourceId, '/')[8]
  scope: resourceGroup(split(VMSubnetResourceId, '/')[2], split(VMSubnetResourceId, '/')[4])
}

resource peVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = if (FslogixStorage != 'None' && PESubnetResourceId != '') {
  name: split(PESubnetResourceId, '/')[8]
  scope: resourceGroup(split(PESubnetResourceId, '/')[2], split(PESubnetResourceId, '/')[4])
}

// Resource Names
module resourceNames 'modules/resourceNames.bicep' = {
  name: 'ResourceNames_${Timestamp}'
  params: {
    Environment: Environment
    Identifier: Identifier
    LocationControlPlane: LocationControlPlane
    LocationVirtualMachines: vmVirtualNetwork.location
    StampIndex: StampIndex
  }
}

// Logic
module logic 'modules/logic.bicep' = {
  name: 'Logic_${Timestamp}'
  params: {
    ActiveDirectorySolution: ActiveDirectorySolution
    ArtifactsLocation: ArtifactsLocation
    DiskSku: DiskSku
    CSEFiles: CSEFiles
    DomainName: DomainName
    FileShareNames: resourceNames.outputs.FileShareNames
    FslogixSolution: FslogixSolution
    FslogixStorage: FslogixStorage
    HostPoolType: HostPoolType
    ImageOffer: ImageOffer
    ImagePublisher: ImagePublisher
    ImageSku: ImageSku
    Locations: resourceNames.outputs.Locations
    LocationVirtualMachines: vmVirtualNetwork.location
    ResourceGroupControlPlane: resourceNames.outputs.ResourceGroupControlPlane
    ResourceGroupHosts: resourceNames.outputs.ResourceGroupHosts
    ResourceGroupManagement: resourceNames.outputs.ResourceGroupManagement
    ResourceGroupStorage: resourceNames.outputs.ResourceGroupStorage
    SecurityPrincipals: SecurityPrincipals
    SessionHostCount: SessionHostCount
    SessionHostIndex: SessionHostIndex
    StorageCount: StorageCount
    VirtualMachineNamePrefix: resourceNames.outputs.VirtualMachineNamePrefix
    VirtualMachineSize: VirtualMachineSize
  }
}

// Resource Groups
module rgs 'modules/resourceGroups.bicep' = {
  name: 'ResourceGroups_${Timestamp}'
  params: {
    LocationControlPlane: LocationControlPlane
    LocationVirtualMachines: vmVirtualNetwork.location
    ResourceGroups: logic.outputs.ResourceGroups
    Tags: Tags
  }
}

// Management Services: Logging, Automation, Keys, Encryption
module management 'modules/management/management.bicep' = {
  name: 'Management_${Timestamp}'
  params: {
    ActiveDirectorySolution: ActiveDirectorySolution
    ArtifactsLocation: logic.outputs.ArtifactsLocation
    ArtifactsStorageAccountResourceId: ArtifactsStorageAccountResourceId
    ArtifactsUserAssignedIdentityResourceId: ArtifactsUserAssignedIdentityResourceId
    AutomationAccountName: resourceNames.outputs.AutomationAccountName
    Availability: Availability
    AvdObjectId: AvdObjectId
    LocationControlPlane: LocationControlPlane
    DiskEncryption: DiskEncryption
    DiskEncryptionSetName: resourceNames.outputs.DiskEncryptionSetName
    DiskNamePrefix: resourceNames.outputs.DiskNamePrefix
    DiskSku: DiskSku
    DomainJoinPassword: DomainJoinPassword
    DomainJoinUserPrincipalName: DomainJoinUserPrincipalName
    DomainName: DomainName
    DrainMode: DrainMode
    Environment: Environment
    Fslogix: logic.outputs.Fslogix
    FslogixSolution: FslogixSolution
    FslogixStorage: FslogixStorage
    HostPoolType: HostPoolType
    KerberosEncryption: KerberosEncryption
    KeyVaultName: resourceNames.outputs.KeyVaultName
    LogAnalyticsWorkspaceName: resourceNames.outputs.LogAnalyticsWorkspaceName
    LogAnalyticsWorkspaceRetention: LogAnalyticsWorkspaceRetention
    LogAnalyticsWorkspaceSku: LogAnalyticsWorkspaceSku
    Monitoring: Monitoring
    NetworkInterfaceNamePrefix: resourceNames.outputs.NetworkInterfaceNamePrefix
    PooledHostPool: logic.outputs.PooledHostPool
    RecoveryServices: RecoveryServices
    RecoveryServicesVaultName: resourceNames.outputs.RecoveryServicesVaultName
    ResourceGroupControlPlane: resourceNames.outputs.ResourceGroupControlPlane
    ResourceGroupManagement: resourceNames.outputs.ResourceGroupManagement
    ResourceGroupStorage: resourceNames.outputs.ResourceGroupStorage
    RoleDefinitions: logic.outputs.RoleDefinitions
    ScalingTool: ScalingTool
    SessionHostCount: SessionHostCount
    StorageSolution: logic.outputs.StorageSolution
    SubnetResourceId: PESubnetResourceId
    Tags: Tags
    Timestamp: Timestamp
    TimeZone: logic.outputs.TimeZone
    UserAssignedIdentityName: resourceNames.outputs.UserAssignedIdentityName
    LocationVirtualMachines: vmVirtualNetwork.location
    VirtualMachineNamePrefix: resourceNames.outputs.VirtualMachineNamePrefix
    VirtualMachinePassword: VirtualMachinePassword
    VirtualMachineSize: VirtualMachineSize
    VirtualMachineUsername: VirtualMachineUsername
    WorkspaceFriendlyName: WorkspaceFriendlyName
    WorkspaceName: resourceNames.outputs.WorkspaceName
  }
  dependsOn: [
    rgs
  ]
}

// AVD Control Plane Resources
// This module deploys the host pool and desktop application group
module controlPlane 'modules/controlPlane/controlPlane.bicep' = {
  name: 'ControlPlane_${Timestamp}'
  params: {
    ActiveDirectorySolution: ActiveDirectorySolution
    CustomRdpProperty: CustomRdpProperty
    DesktopApplicationGroupName: resourceNames.outputs.DesktopApplicationGroupName
    HostPoolName: resourceNames.outputs.HostPoolName
    HostPoolType: HostPoolType
    Location: LocationControlPlane
    LogAnalyticsWorkspaceResourceId: Monitoring ? management.outputs.LogAnalyticsWorkspaceResourceId : ''
    MaxSessionLimit: MaxSessionLimit
    Monitoring: Monitoring
    RoleDefinitions: logic.outputs.RoleDefinitions
    ResourceGroupControlPlane: resourceNames.outputs.ResourceGroupControlPlane
    ResourceGroupManagement: resourceNames.outputs.ResourceGroupManagement
    SecurityPrincipalObjectIds: map(SecurityPrincipals, item => item.objectId)
    TagsApplicationGroup: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.DesktopVirtualization/applicationGroups') ? Tags['Microsoft.DesktopVirtualization/applicationGroups'] : {})
    TagsHostPool: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.DesktopVirtualization/hostPools') ? Tags['Microsoft.DesktopVirtualization/hostPools'] : {})
    Timestamp: Timestamp
    ValidationEnvironment: ValidationEnvironment
    VmTemplate: logic.outputs.VmTemplate
    WorkspaceFriendlyName: WorkspaceFriendlyName
    WorkspaceName: resourceNames.outputs.WorkspaceName
  }
  dependsOn: [
    rgs
  ]
}

module fslogix 'modules/fslogix/fslogix.bicep' = if (FslogixStorage != 'None') {
  name: 'FSLogix_${Timestamp}'
  params: {
    ArtifactsLocation: logic.outputs.ArtifactsLocation
    ArtifactsUserAssignedIdentityClientId: management.outputs.ArtifactsUserAssignedIdentityClientId
    ActiveDirectoryConnection: management.outputs.ValidateANFfActiveDirectory
    ActiveDirectorySolution: ActiveDirectorySolution
    AutomationAccountName: resourceNames.outputs.AutomationAccountName
    Availability: Availability
    AzureFilesPrivateDnsZoneResourceId: AzureFilesPrivateDnsZoneResourceId
    AzureFilesUserAssignedIdentityClientId: management.outputs.UserAssignedIdentityClientId
    DelegatedSubnetId: management.outputs.ValidateANFSubnetId
    DnsServers: management.outputs.ValidateANFDnsServers
    DomainJoinPassword: DomainJoinPassword
    DomainJoinUserPrincipalName: DomainJoinUserPrincipalName
    DomainName: DomainName
    FileShares: logic.outputs.FileShares
    FslogixShareSizeInGB: FslogixShareSizeInGB
    FslogixSolution: FslogixSolution
    FslogixStorage: FslogixStorage
    KerberosEncryption: KerberosEncryption
    Location: peVirtualNetwork.location
    ManagementVmName: management.outputs.VirtualMachineName
    NetAppAccountName: resourceNames.outputs.NetAppAccountName
    NetAppCapacityPoolName: resourceNames.outputs.NetAppCapacityPoolName
    Netbios: logic.outputs.Netbios
    OuPath: OuPath
    PrivateEndpoint: logic.outputs.PrivateEndpoint
    RecoveryServices: RecoveryServices
    RecoveryServicesVaultName: resourceNames.outputs.RecoveryServicesVaultName
    ResourceGroupManagement: resourceNames.outputs.ResourceGroupManagement
    ResourceGroupStorage: resourceNames.outputs.ResourceGroupStorage
    SecurityPrincipalObjectIds: map(SecurityPrincipals, item => item.objectId)
    SecurityPrincipalNames: map(SecurityPrincipals, item => item.name)
    SmbServerLocation: logic.outputs.SmbServerLocation
    StorageAccountNamePrefix: resourceNames.outputs.StorageAccountNamePrefix
    StorageCount: logic.outputs.StorageCount
    StorageIndex: StorageIndex
    StorageSku: logic.outputs.StorageSku
    StorageSolution: logic.outputs.StorageSolution
    Subnet: split(PESubnetResourceId, '/')[10]
    TagsAutomationAccounts: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/workspaces/${resourceNames.outputs.WorkspaceName}'
    }, contains(Tags, 'Microsoft.Automation/automationAccounts') ? Tags['Microsoft.Automation/automationAccounts'] : {})
    TagsNetAppAccount: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.NetApp/netAppAccounts') ? Tags['Microsoft.NetApp/netAppAccounts'] : {})
    TagsPrivateEndpoints: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.Network/privateEndpoints') ? Tags['Microsoft.Network/privateEndpoints'] : {})
    TagsStorageAccounts: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.Storage/storageAccounts') ? Tags['Microsoft.Storage/storageAccounts'] : {})
    TagsRecoveryServicesVault: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.RecoveryServices/vaults') ? Tags['Microsoft.RecoveryServices/vaults'] : {})
    TagsVirtualMachines: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.Compute/virtualMachines') ? Tags['Microsoft.Compute/virtualMachines'] : {})
    Timestamp: Timestamp
    TimeZone: logic.outputs.TimeZone
    VirtualNetwork: split(PESubnetResourceId, '/')[8]
    VirtualNetworkResourceGroup: split(PESubnetResourceId, '/')[4]
  }
}

module sessionHosts 'modules/sessionHosts/sessionHosts.bicep' = {
  name: 'SessionHosts_${Timestamp}'
  params: {
    AcceleratedNetworking: management.outputs.ValidateAcceleratedNetworking
    ActiveDirectorySolution: ActiveDirectorySolution
    ArtifactsLocation: logic.outputs.ArtifactsLocation
    //ArtifactsStorageAccountResourceId: ArtifactsStorageAccountResourceId
    ArtifactsUserAssignedIdentityClientId: management.outputs.ArtifactsUserAssignedIdentityClientId //ClientId that comes from Management / UserAssignedIdentity Modules is already determined.
    ArtifactsUserAssignedIdentityResourceId: !empty(ArtifactsUserAssignedIdentityResourceId) ? ArtifactsUserAssignedIdentityResourceId : management.outputs.UserAssignedIdentityResourceId
    AutomationAccountName: resourceNames.outputs.AutomationAccountName
    Availability: Availability
    AvailabilitySetNamePrefix: resourceNames.outputs.AvailabilitySetNamePrefix
    AvailabilitySetsCount: logic.outputs.AvailabilitySetsCount
    AvailabilitySetsIndex: logic.outputs.BeginAvSetRange
    AvailabilityZones: management.outputs.ValidateAvailabilityZones
    CSEScriptAddDynParameters: CSEScriptAddDynParameters
    CSEUris: logic.outputs.CSEUris
    DiskEncryption: DiskEncryption
    DiskEncryptionSetResourceId: DiskEncryption ? management.outputs.DiskEncryptionSetResourceId : ''
    DiskNamePrefix: resourceNames.outputs.DiskNamePrefix
    DiskSku: DiskSku
    DivisionRemainderValue: logic.outputs.DivisionRemainderValue
    DomainJoinPassword: DomainJoinPassword
    DomainJoinUserPrincipalName: DomainJoinUserPrincipalName
    DomainName: DomainName  
    DrainMode: DrainMode
    DrainModeUserAssignedIdentityClientId: management.outputs.UserAssignedIdentityClientId
    FslogixSolution: FslogixSolution
    FslogixExistingStorageAccountResourceIds: FslogixExistingStorageAccountResourceIds
    FslogixConfigureSessionHosts: FslogixConfigureSessionHosts
    FslogixDeployed: logic.outputs.Fslogix
    HostPoolName: resourceNames.outputs.HostPoolName
    ImageOffer: ImageOffer
    ImagePublisher: ImagePublisher
    ImageSku: ImageSku
    ImageVersionResourceId: ImageVersionResourceId
    Location: vmVirtualNetwork.location
    LogAnalyticsWorkspaceName: resourceNames.outputs.LogAnalyticsWorkspaceName
    ManagementVMName: management.outputs.VirtualMachineName
    MaxResourcesPerTemplateDeployment: logic.outputs.MaxResourcesPerTemplateDeployment
    Monitoring: Monitoring
    NetAppFileShares: FslogixConfigureSessionHosts? fslogix.outputs.netAppShares : [
      'None'
    ]
    NetworkInterfaceNamePrefix: resourceNames.outputs.NetworkInterfaceNamePrefix
    OuPath: OuPath
    PooledHostPool: logic.outputs.PooledHostPool
    RecoveryServices: RecoveryServices
    RecoveryServicesVaultName: resourceNames.outputs.RecoveryServicesVaultName
    ResourceGroupControlPlane: resourceNames.outputs.ResourceGroupControlPlane
    ResourceGroupHosts: resourceNames.outputs.ResourceGroupHosts
    ResourceGroupManagement: resourceNames.outputs.ResourceGroupManagement
    ResourceGroupStorage: resourceNames.outputs.ResourceGroupStorage
    RoleDefinitions: logic.outputs.RoleDefinitions
    RunBookUpdateUserAssignedIdentityClientId: management.outputs.UserAssignedIdentityClientId
    ScalingBeginPeakTime: ScalingBeginPeakTime
    ScalingEndPeakTime: ScalingEndPeakTime
    ScalingLimitSecondsToForceLogOffUser: ScalingLimitSecondsToForceLogOffUser
    ScalingMinimumNumberOfRdsh: ScalingMinimumNumberOfRdsh
    ScalingSessionThresholdPerCPU: ScalingSessionThresholdPerCPU
    ScalingTool: ScalingTool
    SecurityPrincipalObjectIds: map(SecurityPrincipals, item => item.objectId)
    SecurityLogAnalyticsWorkspaceResourceId: SecurityLogAnalyticsWorkspaceResourceId
    SessionHostBatchCount: logic.outputs.SessionHostBatchCount
    SessionHostIndex: SessionHostIndex
    StorageAccountPrefix: resourceNames.outputs.StorageAccountNamePrefix
    StorageCount: logic.outputs.StorageCount
    StorageIndex: StorageIndex
    StorageSolution: logic.outputs.StorageSolution
    StorageSuffix: logic.outputs.StorageSuffix
    Subnet: split(VMSubnetResourceId, '/')[10]
    TagsAvailabilitySets: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.Compute/availabilitySets') ? Tags['Microsoft.Compute/availabilitySets'] : {})
    TagsNetworkInterfaces: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.Network/networkInterfaces') ? Tags['Microsoft.Network/networkInterfaces'] : {})
    TagsRecoveryServicesVault: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.RecoveryServices/vaults') ? Tags['Microsoft.RecoveryServices/vaults'] : {})
    TagsVirtualMachines: union({
      'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.ResourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostpools/${resourceNames.outputs.HostPoolName}'
    }, contains(Tags, 'Microsoft.Compute/virtualMachines') ? Tags['Microsoft.Compute/virtualMachines'] : {})
    TimeDifference: logic.outputs.TimeDifference
    Timestamp: Timestamp
    TimeZone: logic.outputs.TimeZone
    TrustedLaunch: management.outputs.ValidateTrustedLaunch
    VirtualMachineNamePrefix: resourceNames.outputs.VirtualMachineNamePrefix
    VirtualMachinePassword: VirtualMachinePassword
    VirtualMachineSize: VirtualMachineSize
    VirtualMachineUsername: VirtualMachineUsername
    VirtualNetwork: split(VMSubnetResourceId, '/')[8]
    VirtualNetworkResourceGroup: split(VMSubnetResourceId, '/')[4]
  }
  dependsOn: [
    rgs
  ]
}
