targetScope = 'subscription'

@description('The URL prefix for linked resources.')
param _artifactsLocation string = 'https://raw.githubusercontent.com/jamasten/AzureVirtualDesktop/main/artifacts/'

@secure()
@description('The SAS Token for the scripts if they are stored on an Azure Storage Account.')
param _artifactsLocationSasToken string = ''

@allowed([
  'AvailabilitySet'
  'AvailabilityZones'
  'None'
])
@description('Set the desired availability / SLA with a pooled host pool.  Choose "None" if deploying a personal host pool.')
param Availability string = 'None'

@description('The Object ID for the Windows Virtual Desktop Enterprise Application in Azure AD.  The Object ID can found by selecting Microsoft Applications using the Application type filter in the Enterprise Applications blade of Azure AD.')
param AvdObjectId string

@description('If using private endpoints with Azure Files, input the Resource ID for the Private DNS Zone linked to your hub virtual network.')
param AzureFilesPrivateDnsZoneResourceId string = ''

@description('Input RDP properties to add or remove RDP functionality on the AVD host pool. Settings reference: https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/rdp-files?context=/azure/virtual-desktop/context/context')
param CustomRdpProperty string = 'audiocapturemode:i:1;camerastoredirect:s:*;use multimon:i:0;drivestoredirect:s:;'

@description('Enable BitLocker encrytion on the AVD session hosts and management VM.')
param DiskEncryption bool = false

@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
@description('The storage SKU for the AVD session host disks.  Production deployments should use Premium_LRS.')
param DiskSku string = 'Standard_LRS'

@secure()
@description('The password of the privileged account to domain join the AVD session hosts to your domain')
param DomainJoinPassword string

@description('The UPN of the privileged account to domain join the AVD session hosts to your domain. This should be an account the resides within the domain you are joining.')
param DomainJoinUserPrincipalName string

@description('The name of the domain that provides ADDS to the AVD session hosts and is synchronized with Azure AD')
param DomainName string = 'jasonmasten.com'

@allowed([
  'ActiveDirectory' // Active Directory Domain Services
  'AzureActiveDirectory' // Azure Active Directory Domain Services
  'None' // Azure AD Join
  'NoneWithIntune' // Azure AD Join with Intune enrollment
])
@description('The service providing domain services for Azure Virtual Desktop.  This is needed to determine the proper solution to domain join the Azure Storage Account.')
param DomainServices string = 'AzureActiveDirectory'

@description('Enable drain mode on sessions hosts during deployment to prevent users from accessing the session hosts.')
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
param FslogixShareSizeInGB int

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
  'AzureNetAppFiles Ultra' // ANF with the Ultra SKU, 450,000 IOPS
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

@description('Version for the virtual machine image')
param ImageVersion string = 'latest'

@allowed([
  'AES256'
  'RC4'
])
@description('The Active Directory computer object Kerberos encryption type for the Azure Storage Account or Azure NetApp Files Account.')
param KerberosEncryption string = 'RC4'

param Location string = deployment().location

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
param MaxSessionLimit int = 2

@description('Deploys the required monitoring resources to enable AVD Insights and monitor features in the automation account.')
param Monitoring bool = true

@description('The distinguished name for the target Organization Unit in Active Directory Domain Services.')
param OuPath string

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

@description('Determines whether the Screen Capture Protection feature is enabled.  As of 9/17/21 this is only supported in Azure Cloud. https://docs.microsoft.com/en-us/azure/virtual-desktop/screen-capture-protection')
param ScreenCaptureProtection bool = false

@description('An array of Object IDs for the Security Principals to assign to the AVD Application Group and FSLogix Storage.')
param SecurityPrincipalObjectIds array = []

@description('The name for the Security Principal to assign NTFS permissions on the Azure File Share to support Fslogix.  Any value can be input in this field if performing a deployment update or choosing a personal host pool.')
param SecurityPrincipalNames array = []

@description('The name of the log analytics workspace used for Azure Sentinel.')
param SentinelLogAnalyticsWorkspaceName string = ''

@description('The name of the resource group containing the log analytics workspace used for Azure Sentinel.')
param SentinelLogAnalyticsWorkspaceResourceGroupName string = ''

@description('The ID of the subscription containing the log analytics workspace used for Azure Sentinel.')
param SentinelLogAnalyticsWorkspaceSubscriptionId string = subscription().subscriptionId

@description('The number of session hosts to deploy in the host pool.  The default values will allow you deploy 250 VMs using 4 nested deployments.  These integers may be modified to create a smaller deployment in a shard.')
param SessionHostCount int = 1

@description('The session host number to begin with for the deployment. This is important when adding virtual machines to ensure the names do not conflict.')
param SessionHostIndex int = 0

@description('The stamp index specifies the AVD stamp within an Azure environment.')
param StampIndex int = 0

@description('Determines whether the Start VM On Connect feature is enabled. https://docs.microsoft.com/en-us/azure/virtual-desktop/start-virtual-machine-connect')
param StartVmOnConnect bool = true

@description('The Storage Count allows the deployment of one or more storage resources within an AVD stamp to shard for extra capacity. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding')
param StorageCount int = 1

@description('The Storage Index allows the deployment of one or more storage resources within an AVD stamp to shard for extra capacity. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding')
param StorageIndex int = 0

@description('The subnet for the AVD session hosts.')
param SubnetName string = 'Clients'

@description('Key / value pairs of metadata for the Azure resources.')
param Tags object = {
  Owner: 'Jason Masten'
  Environment: 'Development'
}

@description('DO NOT MODIFY THIS VALUE! The timestamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param Timestamp string = utcNow('yyyyMMddhhmmss')

@description('The value determines whether the hostpool should receive early AVD updates for testing.')
param ValidationEnvironment bool = false

@description('Virtual network for the AVD sessions hosts')
param VirtualNetworkName string

@description('Virtual network resource group for the AVD sessions hosts')
param VirtualNetworkResourceGroupName string

@secure()
@description('Local administrator password for the AVD session hosts')
param VmPassword string

@description('The VM SKU for the AVD session hosts.')
param VmSize string = 'Standard_D4ds_v4'

@description('The Local Administrator Username for the Session Hosts')
param VmUsername string

/*  BEGIN BATCHING SESSION HOSTS */
// The following variables are used to determine the batches to deploy any number of AVD session hosts.
var MaxResourcesPerTemplateDeployment = 79 // This is the max number of session hosts that can be deployed from the sessionHosts.bicep file in each batch / for loop. Math: (800 - <Number of Static Resources>) / <Number of Looped Resources> 
var DivisionValue = SessionHostCount / MaxResourcesPerTemplateDeployment // This determines if any full batches are required.
var DivisionRemainderValue = SessionHostCount % MaxResourcesPerTemplateDeployment // This determines if any partial batches are required.
var SessionHostBatchCount = DivisionRemainderValue > 0 ? DivisionValue + 1 : DivisionValue // This determines the total number of batches needed, whether full and / or partial.
/*  END BATCHING SESSION HOSTS */

/*  BEGIN BATCHING AVAILABILITY SETS */
// The following variables are used to determine the number of availability sets.
var MaxAvSetMembers = 200 // This is the max number of session hosts that can be deployed in an availability set.
var BeginAvSetRange = SessionHostIndex / MaxAvSetMembers // This determines the availability set to start with.
var EndAvSetRange = (SessionHostCount + SessionHostIndex) / MaxAvSetMembers // This determines the availability set to end with.
var AvailabilitySetCount = length(range(BeginAvSetRange, (EndAvSetRange - BeginAvSetRange) + 1))
/*  END BATCHING AVAILABILITY SETS */

var AppGroupName = 'dag-${NamingStandard}'
var AvailabilitySetPrefix = 'as-${NamingStandard}'
var AutomationAccountName = 'aa-${NamingStandard}'
var ConfigurationName = 'Windows10'
var DeploymentScriptNamePrefix = 'ds-${NamingStandard}-'
var DesktopVirtualizationPowerOnContributorRoleDefinitionResourceId = resourceId('Microsoft.Authorization/roleDefinitions', '489581de-a3bd-480d-9518-53dea7416b33')
var DiskName = 'disk-${NamingStandard}'
var FileShareNames = {
  CloudCacheProfileContainer: [
    'profile-containers'
  ]
  CloudCacheProfileOfficeContainer: [
    'office-containers'
    'profile-containers'
  ]
  ProfileContainer: [
    'profile-containers'
  ]
  ProfileOfficeContainer: [
    'office-containers'
    'profile-containers'
  ]
}
var FileShares = FileShareNames[FslogixSolution]
var Fslogix = FslogixStorage == 'None' || contains(DomainServices, 'None') ? false : true
var HostPoolName = 'hp-${NamingStandard}'
var KeyVaultName = 'kv-${NamingStandard}'
var Locations = loadJsonContent('artifacts/locations.json')
var LocationShortName = Locations[Location].acronym
var LogAnalyticsWorkspaceName = 'law-${NamingStandard}'
var UserAssignedIdentityName = 'uami-${NamingStandard}'
var ManagementVmName = '${VmName}mgt'
var NamingStandard = '${Identifier}-${Environment}-${LocationShortName}-${StampIndexFull}'
var NetAppAccountName = 'naa-${NamingStandard}'
var NetAppCapacityPoolName = 'nacp-${NamingStandard}'
var Netbios = split(DomainName, '.')[0]
var PooledHostPool = split(HostPoolType, ' ')[0] == 'Pooled' ? true : false
var PrivateEndpoint = contains(FslogixStorage, 'PrivateEndpoint') ? true : false
var ReaderRoleDefinitionResourceId = resourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
var RecoveryServicesVaultName = 'rsv-${NamingStandard}'
var ResourceGroupHosts = 'rg-${NamingStandard}-hosts'
var ResourceGroupManagement = 'rg-${NamingStandard}-management'
var ResourceGroupStorage = 'rg-${NamingStandard}-storage'
var ResourceGroups = Fslogix ? [
  ResourceGroupManagement
  ResourceGroupHosts
  ResourceGroupStorage
] : [
  ResourceGroupManagement
  ResourceGroupHosts
]
var SecurityPrincipalIdsCount = length(SecurityPrincipalObjectIds)
var SecurityPrincipalNamesCount = length(SecurityPrincipalNames)
var Sentinel = empty(SentinelLogAnalyticsWorkspaceName) || empty(SentinelLogAnalyticsWorkspaceResourceGroupName) ? false : true
var SentinelResourceGroup = Sentinel ? SentinelLogAnalyticsWorkspaceResourceGroupName : ResourceGroupManagement
var StampIndexFull = padLeft(StampIndex, 2, '0')
var StorageAccountPrefix = 'st${Identifier}${Environment}${LocationShortName}${StampIndexFull}'
var StorageSolution = split(FslogixStorage, ' ')[0]
var StorageSku = FslogixStorage == 'None' ? 'None' : split(FslogixStorage, ' ')[1]
var StorageSuffix = environment().suffixes.storage
var VmName = 'vm${Identifier}${Environment}${LocationShortName}${StampIndexFull}'
var VmTemplate = '{"domain":"${DomainName}","galleryImageOffer":"${ImageOffer}","galleryImagePublisher":"${ImagePublisher}","galleryImageSKU":"${ImageSku}","imageType":"Gallery","imageUri":null,"customImageId":null,"namePrefix":"${VmName}","osDiskType":"${DiskSku}","useManagedDisks":true,"vmSize":{"id":"${VmSize}","cores":null,"ram":null},"galleryItemId":"${ImagePublisher}.${ImageOffer}${ImageSku}"}'
var WorkspaceName = 'ws-${NamingStandard}'

// Resource Groups needed for the solution
resource resourceGroups 'Microsoft.Resources/resourceGroups@2020-10-01' = [for i in range(0, length(ResourceGroups)): {
  name: ResourceGroups[i]
  location: Location
  tags: Tags
}]

module userAssignedIdentity 'modules/userAssignedManagedIdentity.bicep' = {
  scope: resourceGroup(ResourceGroupManagement)
  name: 'UserAssignedIdentity_${Timestamp}'
  params: {
    DiskEncryption: DiskEncryption
    DrainMode: DrainMode
    Fslogix: Fslogix
    FslogixStorage: FslogixStorage
    Location: Location
    UserAssignedIdentityName: UserAssignedIdentityName
    ResourceGroupStorage: ResourceGroupStorage
    Timestamp: Timestamp
    VirtualNetworkResourceGroupName: VirtualNetworkResourceGroupName
  }
}

// Role Assignment for Validation
// This role assignment is required to collect validation information
resource roleAssignment_validation 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(UserAssignedIdentityName, ReaderRoleDefinitionResourceId, subscription().id)
  properties: {
    roleDefinitionId: ReaderRoleDefinitionResourceId
    principalId: userAssignedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Validation Deployment Script
// This module validates the selected parameter values and collects required data
module validation 'modules/deploymentScript.bicep' = {
  scope: resourceGroup(ResourceGroupManagement)
  name: 'DeploymentScript_Validation_${Timestamp}'
  params: {
    Arguments: '-Availability ${Availability} -DiskEncryption ${DiskEncryption} -DiskSku ${DiskSku} -DomainName ${DomainName} -DomainServices ${DomainServices} -Environment ${environment().name} -ImageSku ${ImageSku} -KerberosEncryption ${KerberosEncryption} -Location ${Location} -PooledHostPool ${PooledHostPool} -RecoveryServices ${RecoveryServices} -SecurityPrincipalIdsCount ${SecurityPrincipalIdsCount} -SecurityPrincipalNamesCount ${SecurityPrincipalNamesCount} -SessionHostCount ${SessionHostCount} -SessionHostIndex ${SessionHostIndex} -StartVmOnConnect ${StartVmOnConnect} -StorageCount ${StorageCount} -StorageSolution ${StorageSolution} -VmSize ${VmSize} -VnetName ${VirtualNetworkName} -VnetResourceGroupName ${VirtualNetworkResourceGroupName}'
    Location: Location
    Name: '${DeploymentScriptNamePrefix}validation'
    ScriptContainerSasToken: _artifactsLocationSasToken
    ScriptContainerUri: _artifactsLocation
    ScriptName: 'Get-Validation.ps1'
    Timestamp: Timestamp
    UserAssignedIdentityResourceId: userAssignedIdentity.outputs.id
  }
  dependsOn: [
    resourceGroups
  ]
}

resource startVmOnConnect 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (StartVmOnConnect) {
  name: guid(AvdObjectId, DesktopVirtualizationPowerOnContributorRoleDefinitionResourceId, subscription().id)
  properties: {
    roleDefinitionId: DesktopVirtualizationPowerOnContributorRoleDefinitionResourceId
    principalId: AvdObjectId
  }
}

module automationAccount 'modules/automationAccount.bicep' = if (PooledHostPool) {
  name: 'AutomationAccount_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    AutomationAccountName: AutomationAccountName
    Location: Location
    LogAnalyticsWorkspaceResourceId: Monitoring ? logAnalyticsWorkspace.outputs.ResourceId : ''
    Monitoring: Monitoring
  }
  dependsOn: [
    resourceGroups
  ]
}

// AVD Management Resources
// This module deploys the host pool, desktop application group, & workspace
module hostPool 'modules/hostPool.bicep' = {
  name: 'HostPool_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    AppGroupName: AppGroupName
    CustomRdpProperty: CustomRdpProperty
    DomainServices: DomainServices
    HostPoolName: HostPoolName
    HostPoolType: HostPoolType
    Location: Location
    LogAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.outputs.ResourceId
    MaxSessionLimit: MaxSessionLimit
    SecurityPrincipalIds: SecurityPrincipalObjectIds
    StartVmOnConnect: StartVmOnConnect
    Tags: Tags
    ValidationEnvironment: ValidationEnvironment
    VmTemplate: VmTemplate
    WorkspaceName: WorkspaceName
  }
  dependsOn: [
    resourceGroups
  ]
}

// Monitoring Resources for AVD Insights
// This module deploys a Log Analytics Workspace with Windows Events & Windows Performance Counters plus diagnostic settings on the required resources 
module logAnalyticsWorkspace 'modules/logAnalyticsWorkspace.bicep' = if (Monitoring) {
  name: 'Monitoring_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    LogAnalyticsWorkspaceName: LogAnalyticsWorkspaceName
    LogAnalyticsWorkspaceRetention: LogAnalyticsWorkspaceRetention
    LogAnalyticsWorkspaceSku: LogAnalyticsWorkspaceSku
    Location: Location
    Tags: Tags
  }
  dependsOn: [
    resourceGroups
  ]
}

module keyVault 'modules/keyVault.bicep' = if (DiskEncryption) {
  name: 'KeyVault_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    DeploymentScriptNamePrefix: DeploymentScriptNamePrefix
    Environment: Environment
    KeyVaultName: KeyVaultName
    Location: Location
    ManagedIdentityResourceId: userAssignedIdentity.outputs.id
    ResourceGroupManagement: ResourceGroupManagement
    Timestamp: Timestamp
  }
}

module fslogix 'modules/fslogix/fslogix.bicep' = if (Fslogix) {
  name: 'FSLogix_${Timestamp}'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    ActiveDirectoryConnection: validation.outputs.properties.anfActiveDirectory
    AzureFilesPrivateDnsZoneResourceId: AzureFilesPrivateDnsZoneResourceId
    ClientId: userAssignedIdentity.outputs.clientId
    DelegatedSubnetId: validation.outputs.properties.anfSubnetId
    DeploymentScriptNamePrefix: DeploymentScriptNamePrefix
    DiskEncryption: DiskEncryption
    DnsServers: validation.outputs.properties.anfDnsServers
    DomainJoinPassword: DomainJoinPassword
    DomainJoinUserPrincipalName: DomainJoinUserPrincipalName
    DomainName: DomainName
    DomainServices: DomainServices
    FileShares: FileShares
    FslogixShareSizeInGB: FslogixShareSizeInGB
    FslogixSolution: FslogixSolution
    FslogixStorage: FslogixStorage
    KerberosEncryption: KerberosEncryption
    KeyVaultName: KeyVaultName
    Location: Location
    ManagementVmName: ManagementVmName
    NamingStandard: NamingStandard
    NetAppAccountName: NetAppAccountName
    NetAppCapacityPoolName: NetAppCapacityPoolName
    Netbios: Netbios
    OuPath: OuPath
    PrivateEndpoint: PrivateEndpoint
    ResourceGroupManagement: ResourceGroupManagement
    ResourceGroupStorage: ResourceGroupStorage
    SecurityPrincipalIds: SecurityPrincipalObjectIds
    SecurityPrincipalNames: SecurityPrincipalNames
    SmbServerLocation: LocationShortName
    StorageAccountPrefix: StorageAccountPrefix
    StorageCount: StorageCount
    StorageIndex: StorageIndex
    StorageSku: StorageSku
    StorageSolution: StorageSolution
    Subnet: SubnetName
    Tags: Tags
    Timestamp: Timestamp
    UserAssignedIdentityResourceId: userAssignedIdentity.outputs.id
    VirtualNetwork: VirtualNetworkName
    VirtualNetworkResourceGroup: VirtualNetworkResourceGroupName
    VmPassword: VmPassword
    VmUsername: VmUsername
  }
  dependsOn: [
    keyVault
    userAssignedIdentity
  ]
}

module sentinel 'modules/sentinel.bicep' = {
  name: 'Sentinel_${Timestamp}'
  scope: resourceGroup(SentinelLogAnalyticsWorkspaceSubscriptionId, SentinelResourceGroup)
  params: {
    Sentinel: Sentinel
    SentinelLogAnalyticsWorkspaceName: SentinelLogAnalyticsWorkspaceName
    SentinelLogAnalyticsWorkspaceResourceGroupName: SentinelLogAnalyticsWorkspaceResourceGroupName
  }
  dependsOn: [
    resourceGroups
  ]
}

module sessionHosts 'modules/sessionHosts/sessionHosts.bicep' = {
  name: 'SessionHosts_${Timestamp}'
  scope: resourceGroup(ResourceGroupHosts)
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    AcceleratedNetworking: validation.outputs.properties.acceleratedNetworking
    Availability: Availability
    AvailabilitySetCount: AvailabilitySetCount
    AvailabilitySetPrefix: AvailabilitySetPrefix
    AvailabilitySetIndex: BeginAvSetRange
    DeploymentScriptNamePrefix: DeploymentScriptNamePrefix
    DiskEncryption: DiskEncryption
    DiskName: DiskName
    DiskSku: DiskSku
    DivisionRemainderValue: DivisionRemainderValue
    DomainJoinPassword: DomainJoinPassword
    DomainJoinUserPrincipalName: DomainJoinUserPrincipalName
    DomainName: DomainName
    DomainServices: DomainServices
    DrainMode: DrainMode
    Fslogix: Fslogix
    FslogixSolution: FslogixSolution
    HostPoolName: HostPoolName
    HostPoolType: HostPoolType
    ImageOffer: ImageOffer
    ImagePublisher: ImagePublisher
    ImageSku: ImageSku
    ImageVersion: ImageVersion
    KeyVaultName: KeyVaultName
    Location: Location
    LogAnalyticsWorkspaceName: LogAnalyticsWorkspaceName
    ManagedIdentityResourceId: userAssignedIdentity.outputs.id
    MaxResourcesPerTemplateDeployment: MaxResourcesPerTemplateDeployment
    Monitoring: Monitoring
    NamingStandard: NamingStandard
    NetAppFileShares: Fslogix ? fslogix.outputs.netAppShares : [
      'None'
    ]
    OuPath: OuPath
    PooledHostPool: PooledHostPool
    ResourceGroupHosts: ResourceGroupHosts
    ResourceGroupManagement: ResourceGroupManagement
    ScreenCaptureProtection: ScreenCaptureProtection
    SecurityPrincipalObjectIds: SecurityPrincipalObjectIds
    Sentinel: Sentinel
    SentinelWorkspaceId: sentinel.outputs.sentinelWorkspaceId
    SentinelWorkspaceResourceId: sentinel.outputs.sentinelWorkspaceResourceId
    SessionHostBatchCount: SessionHostBatchCount
    SessionHostIndex: SessionHostIndex
    StorageAccountPrefix: StorageAccountPrefix
    StorageCount: StorageCount
    StorageIndex: StorageIndex
    StorageSolution: StorageSolution
    StorageSuffix: StorageSuffix
    Subnet: SubnetName
    Tags: Tags
    Timestamp: Timestamp
    TrustedLaunch: validation.outputs.properties.trustedLaunch
    VirtualNetwork: VirtualNetworkName
    VirtualNetworkResourceGroup: VirtualNetworkResourceGroupName
    VmName: VmName
    VmPassword: VmPassword
    VmSize: VmSize
    VmUsername: VmUsername
  }
  dependsOn: [
    keyVault
    logAnalyticsWorkspace
    resourceGroups
  ]
}

module backup 'modules/backup/backup.bicep' = if (RecoveryServices) {
  name: 'Backup_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    DivisionRemainderValue: DivisionRemainderValue
    FileShares: FileShares
    Fslogix: Fslogix
    Location: Location
    MaxResourcesPerTemplateDeployment: MaxResourcesPerTemplateDeployment
    RecoveryServicesVaultName: RecoveryServicesVaultName
    SessionHostBatchCount: SessionHostBatchCount
    SessionHostIndex: SessionHostIndex
    StorageAccountPrefix: StorageAccountPrefix
    StorageCount: StorageCount
    StorageIndex: StorageIndex
    StorageResourceGroupName: ResourceGroupStorage
    StorageSolution: StorageSolution
    Tags: Tags
    Timestamp: Timestamp
    TimeZone: Locations[Location].timeZone
    VmName: VmName
    VmResourceGroupName: ResourceGroupHosts
  }
  dependsOn: [
    fslogix
    sessionHosts
  ]
}

module scalingTool 'modules/scalingTool.bicep' = if (ScalingTool && PooledHostPool) {
  name: 'ScalingTool_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    AutomationAccountName: AutomationAccountName
    BeginPeakTime: ScalingBeginPeakTime
    EndPeakTime: ScalingEndPeakTime
    HostPoolName: HostPoolName
    HostPoolResourceGroupName: ResourceGroupManagement
    LimitSecondsToForceLogOffUser: ScalingLimitSecondsToForceLogOffUser
    Location: Location
    MinimumNumberOfRdsh: ScalingMinimumNumberOfRdsh
    ResourceGroupHosts: ResourceGroupHosts
    ResourceGroupManagement: ResourceGroupManagement
    SessionThresholdPerCPU: ScalingSessionThresholdPerCPU
    TimeDifference: Locations[Location].timeDifference
    TimeZone: Locations[Location].timeZone
  }
  dependsOn: [
    automationAccount
    backup
    sessionHosts
  ]
}

module autoIncreasePremiumFileShareQuota 'modules/autoIncreasePremiumFileShareQuota.bicep' = if (contains(FslogixStorage, 'AzureStorageAccount Premium') && StorageCount > 0) {
  name: 'AutoIncreasePremiumFileShareQuota_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    AutomationAccountName: AutomationAccountName
    Environment: Environment
    Location: Location
    StorageAccountPrefix: StorageAccountPrefix
    StorageCount: StorageCount
    StorageIndex: StorageIndex
    StorageResourceGroupName: ResourceGroupStorage
    Tags: Tags
    Timestamp: Timestamp
    TimeZone: Locations[Location].timeZone
  }
  dependsOn: [
    automationAccount
    backup
    fslogix
  ]
}
