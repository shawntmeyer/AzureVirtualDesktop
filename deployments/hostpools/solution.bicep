targetScope = 'subscription'

// Deployment Prerequisites

@description('Optional. The name of the Azure Blobs container hosting the custom script extension master script and any custom scripts.')
param artifactsContainerName string = 'artifacts'

@description('Optional. The storage account resource Id hosting the custom script extension master script and any custom scripts.')
param artifactsStorageAccountResourceId string = ''

@description('''Conditional.
The Resource Id of the managed identity with Storage Blob Data Reader Access to the artifacts storage Account.
Required when accessing artifacts from the storage account. 
''')
param artifactsUserAssignedIdentityResourceId string = ''

@description('The Object ID for the Windows Virtual Desktop Enterprise Application in Azure AD.  The Object ID can found by selecting Microsoft Applications using the Application type filter in the Enterprise Applications blade of Azure AD.')
param avdObjectId string

@description('Optional. The URL of the AVD Agent and Session Host DSC Configuration.zip.')
param avdAgentsModuleUrl string = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration_1.0.02721.349.zip'

// Resource and Resource Group naming and organization

@allowed([
  'd' // Development
  'p' // Production
  's' // Shared
  't' // Test
  '' // Not Defined
])
@description('Optional. The target environment for the solution.')
param envShortName string = ''

@maxLength(6)
@description('''Optional. Identifier used to describe the business unit (or customer) utilizing AVD in your tenant.
If not specified then centralized AVD Management is assumed and resources and resource groups are named accordingly.
If the "envShortName" is specified, then the length must be 5 or less characters unless the FSLogixCustomStoragePrefix is used.
''')
param businessUnitIdentifier string = ''

@maxLength(8)
@minLength(2)
@description('''Required. An identifier used to distinquish each host pool. This can represent the user or use case.
if the "envShortName" is specified, then the length must be 7 or less characters unless the FSLogixCustomStoragePrefix is used.
''')
param hostPoolIdentifier string

@description('Optional. Reverse the normal Cloud Adoption Framework naming convention by putting the resource type abbreviation at the end of the resource name.')
param nameConvResTypeAtEnd bool = false

@description('''Conditional. When the "businessUnitIdentifier" parameter is not empty, this parameter determines if the AVD Monitoring Resource Group and associated resources
are created in a centralized resource group (does not include "businessUnitIdentifier" in the name) and monitoring resources are named accordingly or if a Business unit
specific AVD management resource group is created and monitoring resources are named accordingly.
If the "businessUnitIdentifier" parameter is left empty ("") then this value has no effect.
''')
param centralizedAVDMonitoring bool = false

// Control Plane Configuration

@description('Optional. The deployment location for the AVD Control Plane resources.')
param locationControlPlane string = deployment().location

@description('Optional. The resource Id of an existing AVD workspace to which the desktop application group will be registered.')
param existingFeedWorkspaceResourceId string = ''

@description('Optional. The friendly name for the AVD workspace that is displayed in the client.')
param workspaceFriendlyName string = ''

@description('Optional. The friendly name for the Desktop in the AVD workspace.')
param desktopFriendlyName string = ''

@allowed([
  'Pooled DepthFirst'
  'Pooled BreadthFirst'
  'Personal Automatic'
  'Personal Direct'
])
@description('Optional. These options specify the host pool type and depending on the type provides the load balancing options and assignment types.')
param hostPoolType string = 'Pooled DepthFirst'

@description('Optional. The maximum number of sessions per AVD session host.')
param hostPoolMaxSessionLimit int = 4

@description('''Optional. Input RDP properties to add or remove RDP functionality on the AVD host pool.
Settings reference: https://learn.microsoft.com/windows-server/remote/remote-desktop-services/clients/rdp-files
''')
param hostPoolRDPProperties string = 'audiocapturemode:i:1;camerastoredirect:s:*;enablerdsaadauth:i:1'

@description('Optional. The value determines whether the hostPool should receive early AVD updates for testing.')
param hostPoolValidationEnvironment bool = false

@description('Optional. An array of object IDs to assign to the AVD Application Group and FSLogix Storage.')
param securityPrincipals array = []

@description('Optional. Determines if the scaling plan is deployed to the host pool.')
param deployScalingPlan bool = false

@description('Optional. The tag used to exclude virtual machines from the scaling plan.')
param scalingPlanExclusionTag string = ''

@description('Optional. The scaling plan weekday ramp up schedule')
param scalingPlanRampUpSchedule object = {
  startTime: '8:00'
  minimumHostsPct: 20
  capacityThresholdPct: 60
  loadBalancingAlgorithm: 'DepthFirst'
}

@description('Optional. The scaling plan weekday peak schedule.')
param scalingPlanPeakSchedule object = {
  startTime: '9:00'
  loadBalancingAlgorithm: 'DepthFirst'
}

@description('Optional. The scaling plan weekday rampdown schedule.')
param scalingPlanRampDownSchedule object = {
  startTime: '17:00'
  minimumHostsPct: 10
  capacityThresholdPct: 90
  loadBalancingAlgorithm: 'DepthFirst'
}

@description('Optional. The scaling plan weakday off peak schedule.')
param scalingPlanOffPeakSchedule object = {
  startTime: '20:00'
  loadBalancingAlgorithm: 'DepthFirst'
}

@description('Optional. Determines if the scaling plan will forcefully log off users when scaling down.')
param scalingPlanForceLogoff bool = false

@description('Optional. The number of minutes to wait before forcefully logging off users when scaling down.')
param scalingPlanMinsBeforeLogoff int = 0

// Session Host Configuration

@description('Optional. Enable drain mode on new sessions hosts to prevent users from accessing them until they are validated.')
param drainMode bool = false

@minLength(2)
@maxLength(12)
@description('Required. The Virtual Machine Name prefix.')
param virtualMachineNamePrefix string

@maxValue(5000)
@minValue(0)
@description('Optional. The number of session hosts to deploy in the host pool. Ensure you have the approved quota to deploy the desired count.')
param sessionHostCount int = 1

@maxValue(4999)
@minValue(0)
@description('Optional. The starting number for the session hosts. This is important when adding virtual machines to ensure an update deployment is not performed on an exiting, active session host.')
param sessionHostIndex int = 1

@description('Required. The resource ID of the subnet to place the network interfaces for the AVD session hosts.')
param virtualMachineSubnetResourceId string

@allowed([
  'Standard'
  'ConfidentialVM'
  'TrustedLaunch'
])
@description('Optional. The Security Type of the AVD Session Hosts.  ConfidentialVM and TrustedLaunch are only available in certain regions.')
param securityType string = 'TrustedLaunch'

@description('Optional. Enable Secure Boot on the Trusted Luanch or Confidential VMs.')
param secureBootEnabled bool = true

@description('Optional. Enable the Virtual TPM on Trusted Launch or Confidential VMs.')
param vTpmEnabled bool = true

@description('Optional. Integrity monitoring enables cryptographic attestation and verification of VM boot integrity along with monitoring alerts if the VM did not boot because attestation failed with the defined baseline.')
param integrityMonitoring bool = true

@description('''Optional. Encryption at host encrypts temporary disks and ephemeral OS disks with platform-managed keys,
OS and data disk caches with the key specified in the "keyManagementDisks" parameter, and flows encrypted to the Storage service.
''')
param encryptionAtHost bool = true

@allowed([
  'PlatformManaged'
  'CustomerManaged'
  'CustomerManagedHSM'
  'PlatformManagedAndCustomerManaged'
  'PlatformManagedAndCustomerManagedHSM'
])
@description('''Optional. The type of encryption key management used for the storage. (Default: "PlatformManaged")
- Platform-managed keys (PMKs) are key encryption keys that are generated, stored, and managed entirely by Azure. Choose Platform Managed for the best balance of security and ease of use.
- Customer-managed keys (CMKs) are key encryption keys that are generated, stored, and managed by you, the customer, in your Azure Key Vault. Choose Customer Managed if you need to meet specific compliance requirements.
- Customer-managed keys (CMKs) storage in a premium KeyVault backed by a Hardware Security Module (HSM). The Hardware Security Module is FIPS 140 Level 3 validated.
- Double encryption is 2 layers of encryption: an infrastructure encryption layer with platform managed keys and a disk encryption layer with customer managed keys defined by disk encryption sets.
Choose Platform Managed and Customer Managed if you need double encryption. This option does not apply to confidential VMs.
- Choose Platform Managed and Customer Managed with HSM if you must incorporate double encryption and protect the customer managed key with the Hardware Security Module. This option does not apply to confidential VMs.
''')
param keyManagementDisks string = 'PlatformManaged'

@description('Optional. Confidential disk encryption is an additional layer of encryption which binds the disk encryption keys to the virtual machine TPM and makes the disk content accessible only to the VM.')
param confidentialVMOSDiskEncryption bool = false

@description('''Optional. The object ID of the Confidential VM Orchestrator enterprise application with application ID "bf7b6499-ff71-4aa2-97a4-f372087be7f0".
This is required when "confidentialVMOSDiskEncryption" is set to "true". You must create this application in your tenant before deploying this solution using the following PowerShell script:
  Connect-AzureAD -Tenant "your tenant ID"
  New-AzureADServicePrincipal -AppId bf7b6499-ff71-4aa2-97a4-f372087be7f0 -DisplayName "Confidential VM Orchestrator"
''')
param confidentialVMOrchestratorObjectId string = ''

@description('Optional. The resource Id of the Dedicated Host on which to deploy the Virtual Machines.')
param dedicatedHostResourceId string = ''

@description('Optional. The resource Id of the Dedicated Host Group on to which the Virtual Machines are to be deployed. The Dedicated Host Group must support Automatic Host Assignment for this value to be used.')
param dedicatedHostGroupResourceId string = ''

@allowed([
  0
  32
  64
  128
  256
  512
  1024
  2048
])
@description('Optional. The size of the OS disk in GB for the AVD session hosts. When set to 0 it defaults to the image size - typically 128 GB.')
param diskSizeGB int = 0

@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
@description('Optional. The storage SKU for the AVD session host disks.  Production deployments should use Premium_LRS.')
param diskSku string = 'Premium_LRS'

@description('Optional. The VM SKU for the AVD session hosts.')
param virtualMachineSize string = 'Standard_D4ads_v5'

@description('Optional. Determines whether or not to enable accelerated networking for the session host VMs.')
param enableAcceleratedNetworking bool = true

@description('Optional. Determines whether or not to enable hibernation for the session host VMs.')
param hibernationEnabled bool = false

@allowed([
  'availabilitySets'
  'availabilityZones'
  'None'
])
@description('Optional. Set the desired availability / SLA with a pooled host pool.  The best practice is to deploy to availability Zones for resilency. Not used when either "dedicatedHostResourceId" or "dedicatedHostGroupResourceId" is specified.')
param availability string = 'availabilityZones'

@description('Conditional. The availability zones allowed for the AVD session hosts deployment location. Used when "availability" is set to "availabilityZones".')
param availabilityZones array = []

@description('Optional. Offer for the virtual machine image')
param imageOffer string = 'office-365'

@description('Optional. Publisher for the virtual machine image')
param imagePublisher string = 'MicrosoftWindowsDesktop'

@description('Optional. SKU for the virtual machine image')
param imageSku string = 'win11-23h2-avd-m365'

@description('Required. The resource ID for the Compute Gallery Image Version. Do not set this value if using a marketplace image.')
param customImageResourceId string = ''

@allowed([
  'ActiveDirectoryDomainServices' // User accounts are sourced from and Session Hosts are joined to same Active Directory domain.
  'EntraDomainServices' // User accounts are sourced from either Azure Active Directory or Active Directory Domain Services and Session Hosts are joined to Azure Active Directory Domain Services.
  'EntraId' // User accounts and Session Hosts are located in Azure Active Directory Only (Cloud Only Scenario)
  'EntraIdIntuneEnrollment' // User accounts and Session Hosts are located in Azure Active Directory Only. Session Hosts are automatically enrolled in Intune. (Cloud Only Scenario)
])
@description('Required. The service providing domain services for Azure Virtual Desktop.  This is needed to properly configure the session hosts and if applicable, the Azure Storage Account.')
param identitySolution string

@secure()
@description('Required. Local administrator password for the AVD session hosts')
param virtualMachineAdminPassword string

@secure()
@description('Required. The Local Administrator Username for the Session Hosts')
param virtualMachineAdminUserName string

@secure()
@description('Conditional. The password of the privileged account to domain join the AVD session hosts to your domain. Required when "identitySolution" contains "DomainServices".')
param domainJoinUserPassword string = ''

@secure()
@description('Conditional. The UPN of the privileged account to domain join the AVD session hosts to your domain. This should be an account the resides within the domain you are joining. Required when "identitySolution" contains "DomainServices".')
param domainJoinUserPrincipalName string = ''

@description('Optional. The name of the domain that provides ADDS to the AVD session hosts and is synchronized with Azure AD')
param domainName string = ''

@description('Optional. The distinguished name for the target Organization Unit in Active Directory Domain Services.')
param ouPath string = ''

@description('''Optional. Array of script (or other artifact) names or full uris that will be downloaded by the Custom Script Extension on each Session Host Virtual Machine.
Either specify the entire URL or just the name of the blob if is located at the fqdn specified by the [artifactsUri] parameter.
''')
param cseBlobNames array = []

@description('Optional. The name of the script and blob that is ran by the Custom Script Extension on Virtual Machines.')
param cseMasterScript string = 'cse_master_script.ps1'

@description('''Additional Custom Dynamic parameters passed to CSE Scripts.
(ex: 'Script2Keys=@([pscustomobject]@{stringValue=\'storageAccountName\';booleanValue=\'false\'});Script3Keys=@([pscustomobject]@{intValue=\'10\'}')
''')
param cseScriptAddDynParameters string = ''

// Profile Storage Configuration

@description('Optional. Determines whether resources to support FSLogix profile storage are deployed.')
param deployFSLogixStorage bool = false

@description('Optional. The custom prefix to use for the name of the Azure files storage accounts to use for FSLogix. If not specified, the name is generated automatically.')
param fslogixStorageCustomPrefix string = ''

@description('Optional. The file share size(s) in GB for the fslogix storage solution.')
param fslogixShareSizeInGB int = 100

@description('Optional. The type of FSLogix containers to use for FSLogix.')
@allowed([
  'CloudCacheProfileContainer' // FSLogix Cloud Cache Profile Container
  'CloudCacheProfileOfficeContainer' // FSLogix Cloud Cache Profile & Office Container
  'ProfileContainer' // FSLogix Profile Container
  'ProfileOfficeContainer' // FSLogix Profile & Office Container
])
param fslogixContainerType string = 'ProfileContainer'

@description('''
Optional. An array of objects, defining the groups of administrators who will be granted full control access to the FSLogix share.
This parameter must include key value pairs with the following keys: "domainName", "samAccountName", and "objectId".
''')
param fslogixShareAdminGroups array = []

@allowed([
  'AzureNetAppFiles Premium' // ANF with the Premium SKU, 450,000 IOPS
  'AzureNetAppFiles Standard' // ANF with the Standard SKU, 320,000 IOPS
  'AzureFiles Premium' // Azure files Premium with a Service Endpoint, 100,000 IOPs
  'AzureFiles Standard' // Azure files Standard with the Large File Share option and the default public endpoint, 20,000 IOPS
])
@description('Optional. The storage service to use for storing FSLogix containers. The service & SKU should provide sufficient IOPS for all of your users. https://docs.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix#performance-requirements')
param fslogixStorageService string = 'AzureFiles Standard'

@description('Optional. The resource Id of the subnet delegated to Microsoft.Netapp/volumes to which the NetApp volume will be attached when the "fslogixStorageService" is "AzureNetAppFiles Premium" or "AzureNetAppFiles Standard".')
param netAppVolumesSubnetResourceId string = ''

@description('Optional. Indicates whether or not there is an existing Active Directory Connection with Azure NetApp Volume.')
param existingSharedActiveDirectoryConnection bool = false

@description('Optional. Enable Automatic File Share Quota Increase for Azure Files Premium.')
param enableIncreaseQuotaAutomation bool = false

@description('Optional. Configure FSLogix agent on the session hosts via local registry keys.')
param fslogixConfigureSessionHosts bool = false

@description('''Optional. Existing FSLogix Storage Account Resource Ids. Only used when fslogixConfigureSessionHosts = "true".
This list will be added to any storage accounts created when setting "fslogixStorageService" to any of the AzureFiles options. 
If "identitySolution" is set to "EntraId" or "EntraIdIntuneEnrollment" then only the first storage account listed will be used.
''')
param fslogixExistingStorageAccountResourceIds array = []

@allowed([
  'AES256'
  'RC4'
])
@description('Optional. The Active Directory computer object Kerberos encryption type for the Azure Storage Account or Azure NetApp files Account.')
param fslogixStorageAccountADKerberosEncryption string = 'AES256'

@maxValue(99)
@minValue(0)
@description('Optional. The starting number for the storage accounts to support the required use case for the AVD stamp. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding')
param fslogixStorageIndex int = 1

@allowed([
  'MicrosoftManaged'
  'CustomerManaged'
  'CustomerManagedHSM'
])
@description('Optional. The type of key management used for the Azure Files storage account encryption.')
param keyManagementFSLogixStorage string = 'MicrosoftManaged'

// Management

@description('Optional. Enable backups to an Azure Recovery Services vault.  For a pooled host pool this will enable backups on the Azure file share.  For a personal host pool this will enable backups on the AVD sessions hosts.')
param recoveryServices bool = false

@description('Optional. Deploys the required monitoring resources to enable AVD and VM Insights and monitor features in the automation account.')
param enableMonitoring bool = true

@maxValue(730)
@minValue(30)
@description('Optional. The retention for the Log Analytics Workspace to setup the AVD monitoring solution')
param logAnalyticsWorkspaceRetention int = 30

@allowed([
  'Free'
  'Standard'
  'Premium'
  'PerNode'
  'PerGB2018'
  'Standalone'
  'CapacityReservation'
])
@description('Optional. The SKU for the Log Analytics Workspace to setup the AVD monitoring solution')
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('Optional. The resource ID of the data collection rule used for Azure Sentinel and / or Defender for Cloud when using the Azure Monitor Agent.')
param securityDataCollectionRulesResourceId string = ''

@description('Optional. The vm size of the management VM.')
param managementVmSize string = 'Standard_B2s'

// Zero Trust

@description('Optional. Create private endpoints for all deployed management and storage resources where applicable.')
param deployPrivateEndpoints bool = false

@description('Conditional. The Resource Id of the subnet on which to create the storage account, keyvault, and other resources private link. Required when "privateEndoints" = true.')
param managementAndStoragePrivateEndpointSubnetResourceId string = ''

@description('Conditional. If using private endpoints with Automation Accounts, input the Resource ID for the Private DNS Zone linked to your hub virtual network. Required when "managementPrivateEndpoints is true.')
param automationAccountPrivateDnsZoneResourceId string = ''

@description('Conditional. If using private endpoints with Azure files, input the Resource ID for the Private DNS Zone linked to your hub virtual network. Required when "storagePrivateEndpoints" is true.')
param azureBlobsPrivateDnsZoneResourceId string = ''

@description('Conditional. If using private endpoints with Azure files, input the Resource ID for the Private DNS Zone linked to your hub virtual network. Required when "storagePrivateEndpoints" is true.')
param azureFilesPrivateDnsZoneResourceId string = ''

@description('Conditional. If using private endpoints with Key Vaults, input the Resource ID for the Private DNS Zone linked to your hub virtual network. Required when "managementPrivateEndpoints" is true.')
param keyVaultPrivateDnsZoneResourceId string = ''

@description('Optional. Deploy the Zero Trust Compliant Disk Access Policy to deny Public Access to the Virtual Machine Managed Disks.')
param deployDiskAccessPolicy bool = false

@allowed([
  'None'
  'HostPool'
  'FeedAndHostPool'
  'All'
])
@description('Optional. Determines if Azure Private Link with Azure Virtual Desktop is enabled. Selecting "None" disables AVD Private Link deployment. Selecting one of the other options enables deployment of the required endpoints.')
param avdPrivateLinkPrivateRoutes string = 'None'

@description('Conditional. The resource ID of the subnet where the hostpool private endpoint will be attached. Required when "avdPrivateLinkPrivateRoutes" is not equal to "None".')
param hostpoolPrivateEndpointSubnetResourceId string = ''

@description('Conditional. The resource Id of the AVD Private Link Private DNS Zone used for feed download and connections to host pools. Required when "avdPrivateLinkPrivateRoutes" is not equal to "None".')
param avdPrivateDnsZoneResourceId string = ''

@allowed([  
  'Disabled'
  'Enabled'
  'EnabledForClientsOnly'
])
@description('''Optional. Allow public access to the hostpool through the control plane. Applicable only when "avdPrivateLinkPrivateRoutes" is not equal to "None". 
  "Enabled" allows this resource to be accessed from both public and private networks.
  "Disabled" allows this resource to only be accessed via private endpoints.
  "EnabledForClientsOnly" allows this resource to be accessed only when the session hosts are configured to use private routes.
''')
param hostPoolPublicNetworkAccess string = 'Enabled'

@description('Conditional. The resource Id of the subnet where the workspace feed private endpoint will be attached. Required when "avdPrivateLinkPrivateRoutes" is set to "FeedAndHostPool" or "All".')
param workspaceFeedPrivateEndpointSubnetResourceId string = ''

@allowed([
  'Disabled'
  'Enabled'
])
@description('''Optional. Defines the public access configuration for the workspace feed. Applicable when "avdPrivateLinkPrivateRoutes" is "FeedAndHostPool" or "All".
  "Enabled" allows the AVD workspace to be accessed from both public and private networks.
  "Disabled" allows this resource to only be accessed via private endpoints.
''')
param workspaceFeedPublicNetworkAccess string = 'Enabled'

@description('Optional. The resource Id of the existing global feed workspace. If provided, then the global feed will not be deployed regardless of other AVD Private Link settings.')
param existingGlobalFeedResourceId string = ''

@description('Conditional. The resource Id of the AVD Private Link global feed Private DNS Zone. Required when the "avdPrivateLinkPrivateRoutes" is set to "All" and the "existingGlobalFeedResourceId" is not provided.')
param globalFeedPrivateDnsZoneResourceId string = ''

@description('Conditional. The resource Id of the subnet to which the global feed workspace private endpoint will be attached. Required when the "avdPrivateLinkPrivateRoutes" is set to "All" and the "existingGlobalFeedResourceId" is not provided.')
param globalFeedPrivateEndpointSubnetResourceId string = ''

// Tags

@description('Optional. Key / value pairs of metadata for the Azure resource groups and resources.')
param tags object = {}

// Non Specified Values
@description('DO NOT MODIFY THIS VALUE! The timeStamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param timeStamp string = utcNow('yyyyMMddhhmmss')

// VARIABLES

var artifactsStorageAccountName = !empty(artifactsStorageAccountResourceId) ? last(split(artifactsStorageAccountResourceId, '/')) : ''
var artifactsUri = !empty(artifactsStorageAccountName) ? 'https://${artifactsStorageAccountName}.blob.${environment().suffixes.storage}/${artifactsContainerName}/' : ''

var deployDiskAccessResource = contains(hostPoolType, 'Personal') && recoveryServices && deployPrivateEndpoints ? true : false

var locationVirtualMachines = vmVirtualNetwork.location
var locationGlobalFeed = !empty(globalFeedPrivateEndpointSubnetResourceId) ? avdPrivateLinkGlobalFeedNetwork.location : ''

var confidentialVMOSDiskEncryptionType = confidentialVMOSDiskEncryption ? 'DiskWithVMGuestState' : 'VMGuestStateOnly'

var resourceGroupsCount = 3 + (empty(existingFeedWorkspaceResourceId) ? 1 : 0) + (deployFSLogixStorage ? 1 : 0) + (avdPrivateLinkPrivateRoutes == 'All' && !empty(globalFeedPrivateEndpointSubnetResourceId) ? 1 : 0)

module artifactsUserAssignedIdentity 'modules/getUserAssignedIdentity.bicep' = if(!empty(artifactsUserAssignedIdentityResourceId)) {
  name: 'ArtifactsUserAssignedIdentity_${timeStamp}'
  params: {
    userAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
  }
}

// Existing Session Host Virtual Network location
resource vmVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: split(virtualMachineSubnetResourceId, '/')[8]
  scope: resourceGroup(split(virtualMachineSubnetResourceId, '/')[2], split(virtualMachineSubnetResourceId, '/')[4])
}

// Existing  Virtual Network for the AVD Private Link Global Feed Private Endpoint
resource avdPrivateLinkGlobalFeedNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = if (!empty(globalFeedPrivateEndpointSubnetResourceId)) {
  name: split(globalFeedPrivateEndpointSubnetResourceId, '/')[8]
  scope: resourceGroup(split(globalFeedPrivateEndpointSubnetResourceId, '/')[2], split(globalFeedPrivateEndpointSubnetResourceId, '/')[4])
}

// Resource Names
module resourceNames 'modules/resourceNames.bicep' = {
  name: 'ResourceNames_${timeStamp}'
  params: {
    avdPrivateLinkPrivateRoutes: avdPrivateLinkPrivateRoutes
    envShortName: envShortName
    businessUnitIdentifier: businessUnitIdentifier
    centralizedAVDMonitoring: centralizedAVDMonitoring
    fslogixStorageCustomPrefix: fslogixStorageCustomPrefix
    hostPoolIdentifier: hostPoolIdentifier
    locationControlPlane: locationControlPlane
    locationGlobalFeed: locationGlobalFeed
    locationVirtualMachines: locationVirtualMachines
    nameConvResTypeAtEnd: nameConvResTypeAtEnd
    virtualMachineNamePrefix: virtualMachineNamePrefix
    existingFeedWorkspaceResourceId: existingFeedWorkspaceResourceId
  }
}

// Logic
module logic 'modules/logic.bicep' = {
  name: 'Logic_${timeStamp}'
  params: {
    artifactsUri: artifactsUri
    avdPrivateLinkPrivateRoutes: avdPrivateLinkPrivateRoutes
    globalFeedPrivateEndpointSubnetResourceId: globalFeedPrivateEndpointSubnetResourceId
    cseBlobNames: cseBlobNames
    cseMasterScript: cseMasterScript
    customImageResourceId: customImageResourceId
    dedicatedHostGroupResourceId: dedicatedHostGroupResourceId
    dedicatedHostResourceId: dedicatedHostResourceId
    deployFSLogixStorage: deployFSLogixStorage
    deployMonitoring: enableMonitoring
    deployScalingPlan: deployScalingPlan
    diskSizeGB: diskSizeGB
    diskSku: diskSku
    domainName: domainName
    fileShareNames: resourceNames.outputs.fileShareNames
    fslogixConfigureSessionHosts: fslogixConfigureSessionHosts
    fslogixContainerType: fslogixContainerType
    fslogixStorageService: fslogixStorageService
    hibernationEnabled: hibernationEnabled
    hostPoolType: hostPoolType
    identitySolution: identitySolution
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    locations: resourceNames.outputs.locations
    locationVirtualMachines: locationVirtualMachines
    resourceGroupControlPlane: resourceNames.outputs.resourceGroupControlPlane
    resourceGroupGlobalFeed: resourceNames.outputs.resourceGroupGlobalFeed
    resourceGroupHosts: resourceNames.outputs.resourceGroupHosts
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    resourceGroupMonitoring: resourceNames.outputs.resourceGroupMonitoring
    resourceGroupStorage: resourceNames.outputs.resourceGroupStorage
    scalingPlanExclusionTag: scalingPlanExclusionTag
    scalingPlanForceLogoff: scalingPlanForceLogoff
    scalingPlanMinsBeforeLogoff: scalingPlanMinsBeforeLogoff
    scalingPlanRampUpSchedule: scalingPlanRampUpSchedule
    scalingPlanPeakSchedule: scalingPlanPeakSchedule
    scalingPlanRampDownSchedule: scalingPlanRampDownSchedule
    scalingPlanOffPeakSchedule: scalingPlanOffPeakSchedule
    securityPrincipals: securityPrincipals
    sessionHostCount: sessionHostCount
    sessionHostIndex: sessionHostIndex
    securityType: securityType
    secureBootEnabled: secureBootEnabled
    vTpmEnabled: vTpmEnabled
    tags: tags
    virtualMachineNamePrefix: resourceNames.outputs.virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
    workspaceResourceId: existingFeedWorkspaceResourceId
  }
}

// Resource Groups
module rgs 'modules/resourceGroups.bicep' = [for i in range(0, resourceGroupsCount): {
  name: 'ResourceGroup_${i}_${timeStamp}'
  params: {
    location: contains(logic.outputs.resourceGroupNames[i], 'control-plane') ? locationControlPlane : ( contains(logic.outputs.resourceGroupNames[i], 'global-feed') ? locationGlobalFeed : locationVirtualMachines )
    resourceGroupName: logic.outputs.resourceGroupNames[i]
    tags: tags
  }
}]

// Management Services: Logging, Automation, Keys, Encryption
module management 'modules/management/management.bicep' = {
  name: 'Management_${timeStamp}'
  params: {
    automationAccountName: resourceNames.outputs.automationAccountName
    automationAccountPrivateDnsZoneResourceId: automationAccountPrivateDnsZoneResourceId
    avdObjectId: avdObjectId
    azureBlobsPrivateDnsZoneResourceId: azureBlobsPrivateDnsZoneResourceId
    confidentialVMOrchestratorObjectId: confidentialVMOrchestratorObjectId
    confidentialVMOSDiskEncryptionType: confidentialVMOSDiskEncryptionType
    deployDiskAccessPolicy: deployDiskAccessPolicy
    deployDiskAccessResource: deployDiskAccessResource
    deployScalingPlan: deployScalingPlan
    diskAccessName: resourceNames.outputs.diskAccessName
    diskEncryptionSetNames: resourceNames.outputs.diskEncryptionSetNames
    diskSku: diskSku
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainName: domainName
    enableIncreaseQuotaAutomation: enableIncreaseQuotaAutomation
    encryptionAtHost: encryptionAtHost
    envShortName: envShortName
    fslogix: deployFSLogixStorage
    fslogixStorageIndex: fslogixStorageIndex
    keyManagementFSLogixStorage: keyManagementFSLogixStorage
    fslogixStorageService: fslogixStorageService
    fslogixStorageSolution: logic.outputs.fslogixStorageSolution
    hostPoolType: hostPoolType
    identitySolution: identitySolution
    keyVaultNames: resourceNames.outputs.keyVaultNames
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: enableMonitoring ? monitoring.outputs.logAnalyticsWorkspaceResourceId : ''
    managementVmSize: managementVmSize
    enableMonitoring: enableMonitoring
    keyManagementDisks: keyManagementDisks
    privateEndpointSubnetResourceId: managementAndStoragePrivateEndpointSubnetResourceId
    privateEndpoint: deployPrivateEndpoints
    privateEndpointNameConv: resourceNames.outputs.privateEndpointNameConv
    privateEndpointNICNameConv: resourceNames.outputs.privateEndpointNICNameConv
    recoveryServices: recoveryServices
    recoveryServicesVaultName: resourceNames.outputs.recoveryServicesVaultName
    resourceGroupHosts: resourceNames.outputs.resourceGroupHosts
    resourceGroupControlPlane: resourceNames.outputs.resourceGroupControlPlane
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    resourceGroupStorage: resourceNames.outputs.resourceGroupStorage
    roleDefinitions: logic.outputs.roleDefinitions
    storageCount: logic.outputs.fslogixStorageCount
    tags: tags
    timeStamp: timeStamp
    timeZone: logic.outputs.timeZone
    userAssignedIdentityNameConv: resourceNames.outputs.userAssignedIdentityNameConv
    virtualMachineName: resourceNames.outputs.mgmtVirtualMachineName
    virtualMachineNICName: resourceNames.outputs.mgmtVirtualMachineNicName
    virtualMachineDiskName: resourceNames.outputs.mgmtVirtualMachineDiskName
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineAdminUserName: virtualMachineAdminUserName
    virtualMachineSubnetResourceId: virtualMachineSubnetResourceId
  }                
  dependsOn: [
    rgs
  ]
}

module monitoring 'modules/monitoring/monitoring.bicep' = if(enableMonitoring) {
  name: 'Monitoring_${timeStamp}'
  params: {
    dataCollectionEndpointName: resourceNames.outputs.dataCollectionEndpointName
    dataCollectionRulesNameConv: resourceNames.outputs.dataCollectionRulesNameConv
    location: locationVirtualMachines
    logAnalyticsWorkspaceName: resourceNames.outputs.logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRetention:logAnalyticsWorkspaceRetention
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    resourceGroupMonitoring: resourceNames.outputs.resourceGroupMonitoring
    tags: tags
    timeStamp: timeStamp
  }
  dependsOn: [
    rgs
  ]
}

// AVD Control Plane Resources
// This module deploys the workspace, host pool, and desktop application group
module controlPlane 'modules/controlPlane/controlPlane.bicep' = {
  name: 'ControlPlane_${timeStamp}'
  params: {  
    avdPrivateDnsZoneResourceId: avdPrivateDnsZoneResourceId
    avdPrivateLinkPrivateRoutes: avdPrivateLinkPrivateRoutes
    deployScalingPlan: deployScalingPlan
    deploymentUserAssignedIdentityClientId: management.outputs.deploymentUserAssignedIdentityClientId
    desktopApplicationGroupName: resourceNames.outputs.desktopApplicationGroupName
    desktopFriendlyName: desktopFriendlyName
    existingFeedWorkspaceResourceId: existingFeedWorkspaceResourceId
    existingGlobalWorkspaceResourceId: existingGlobalFeedResourceId
    globalFeedPrivateDnsZoneResourceId: globalFeedPrivateDnsZoneResourceId
    globalFeedPrivateEndpointSubnetResourceId: globalFeedPrivateEndpointSubnetResourceId
    globalWorkspaceName: resourceNames.outputs.globalFeedWorkspaceName
    hostPoolMaxSessionLimit: hostPoolMaxSessionLimit
    hostPoolName: resourceNames.outputs.hostPoolName
    hostPoolPrivateEndpointSubnetResourceId: hostpoolPrivateEndpointSubnetResourceId
    hostPoolPublicNetworkAccess: hostPoolPublicNetworkAccess
    hostPoolRDPProperties: hostPoolRDPProperties
    hostPoolType: hostPoolType
    hostPoolValidationEnvironment: hostPoolValidationEnvironment
    identitySolution: identitySolution
    locationControlPlane: locationControlPlane
    locationGlobalFeed: locationGlobalFeed
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: enableMonitoring ? monitoring.outputs.logAnalyticsWorkspaceResourceId : ''
    managementVirtualMachineName: management.outputs.virtualMachineName    
    enableMonitoring: enableMonitoring
    privateEndpointNameConv: resourceNames.outputs.privateEndpointNameConv
    privateEndpointNICNameConv: resourceNames.outputs.privateEndpointNICNameConv    
    resourceGroupControlPlane: resourceNames.outputs.resourceGroupControlPlane
    resourceGroupGlobalFeed: resourceNames.outputs.resourceGroupGlobalFeed
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    roleDefinitions: logic.outputs.roleDefinitions
    scalingPlanExclusionTag: scalingPlanExclusionTag
    securityPrincipals: securityPrincipals
    tags: tags
    timeStamp: timeStamp
    virtualMachineTemplate: logic.outputs.virtualMachineTemplate
    workspaceFriendlyName: workspaceFriendlyName
    workspaceName: resourceNames.outputs.workspaceName
    workspacePublicNetworkAccess: workspaceFeedPublicNetworkAccess
    scalingPlanName: resourceNames.outputs.scalingPlanName
    scalingPlanSchedules: logic.outputs.scalingPlanSchedules
    virtualMachinesTimeZone: logic.outputs.timeZone
    workspaceFeedPrivateEndpointSubnetResourceId: workspaceFeedPrivateEndpointSubnetResourceId
  }
  dependsOn: [
    rgs
  ]
}

module fslogix 'modules/fslogix/fslogix.bicep' = if (deployFSLogixStorage) {
  name: 'FSLogix_${timeStamp}'
  params: {
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: empty(artifactsUserAssignedIdentityResourceId) ? '' : artifactsUserAssignedIdentity.outputs.clientId
    activeDirectoryConnection: existingSharedActiveDirectoryConnection
    automationAccountName: resourceNames.outputs.automationAccountName
    availability: availability
    azureFilesPrivateDnsZoneResourceId: azureFilesPrivateDnsZoneResourceId
    customerManagedKeysEnabled: keyManagementFSLogixStorage != 'MicrosoftManaged' ? true : false
    deploymentUserAssignedIdentityClientId: management.outputs.deploymentUserAssignedIdentityClientId
    netAppVolumesSubnetResourceId: netAppVolumesSubnetResourceId
    domainName: domainName
    enableIncreaseQuotaAutomation: enableIncreaseQuotaAutomation
    encryptionUserAssignedIdentityResourceId: management.outputs.encryptionUserAssignedIdentityResourceId
    fileShares: logic.outputs.fileShares
    fslogixAdminGroupObjectIds: !empty(fslogixShareAdminGroups) ? map(fslogixShareAdminGroups, item => item.objectId) : []
    fslogixAdminGroupSamAccountNames: !empty(fslogixShareAdminGroups) ? map(fslogixShareAdminGroups, item => item.samAccountName) : []
    fslogixAdminGroupDomainNames: !empty(fslogixShareAdminGroups) ? map(fslogixShareAdminGroups, item => item.domainName) : []
    shareSizeInGB: fslogixShareSizeInGB
    containerType: fslogixContainerType
    storageService: fslogixStorageService
    identitySolution: identitySolution
    kerberosEncryption: fslogixStorageAccountADKerberosEncryption
    vmKeyVaultName: resourceNames.outputs.keyVaultNames.VMs
    storageEncryptionKeyVaultUris: management.outputs.storageEncryptionKeyKeyVaultUris
    location: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: enableMonitoring ? monitoring.outputs.logAnalyticsWorkspaceResourceId : ''
    managementVirtualMachineName: management.outputs.virtualMachineName
    netAppAccountName: resourceNames.outputs.netAppAccountName
    netAppCapacityPoolName: resourceNames.outputs.netAppCapacityPoolName
    netbios: logic.outputs.netbios
    ouPath: ouPath
    privateEndpoint: deployPrivateEndpoints
    privateEndpointNameConv: resourceNames.outputs.privateEndpointNameConv
    privateEndpointNICNameConv: resourceNames.outputs.privateEndpointNICNameConv
    recoveryServices: recoveryServices
    recoveryServicesVaultName: resourceNames.outputs.recoveryServicesVaultName
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    resourceGroupStorage: resourceNames.outputs.resourceGroupStorage
    securityPrincipals: securityPrincipals
    smbServerLocation: logic.outputs.smbServerLocation
    storageAccountNamePrefix: resourceNames.outputs.storageAccountNamePrefix
    storageCount: logic.outputs.fslogixStorageCount
    storageEncryptionKeyName: management.outputs.storageAccountEncryptionKeyName
    storageIndex: fslogixStorageIndex
    storageSku: logic.outputs.fslogixStorageSku
    storageSolution: logic.outputs.fslogixStorageSolution
    privateEndpointSubnetResourceId: managementAndStoragePrivateEndpointSubnetResourceId
    tagsAutomationAccounts: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/workspaces/${resourceNames.outputs.workspaceName}'
      }, tags[?'Microsoft.Automation/automationAccounts'] ?? {})
    tagsNetAppAccount: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostPools/${resourceNames.outputs.hostPoolName}'
      }, tags[?'Microsoft.NetApp/netAppAccounts'] ?? {})
    tagsPrivateEndpoints: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostPools/${resourceNames.outputs.hostPoolName}'
      }, tags[?'Microsoft.Network/privateEndpoints'] ?? {})
    tagsStorageAccounts: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostPools/${resourceNames.outputs.hostPoolName}'
      }, tags[?'Microsoft.Storage/storageAccounts'] ?? {})
    tagsRecoveryServicesVault: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostPools/${resourceNames.outputs.hostPoolName}'
      }, tags[?'Microsoft.recoveryServices/vaults'] ?? {})
    timeStamp: timeStamp
    timeZone: logic.outputs.timeZone
  }
  dependsOn: [
    controlPlane
  ]
}

module sessionHosts 'modules/sessionHosts/sessionHosts.bicep' = {
  name: 'SessionHosts_${timeStamp}'
  params: {
    avdAgentsModuleUrl: avdAgentsModuleUrl
    artifactsUserAssignedIdentityClientId: empty(artifactsUserAssignedIdentityResourceId) ? '': artifactsUserAssignedIdentity.outputs.clientId
    artifactsUserAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
    availability: availability
    availabilitySetNamePrefix: resourceNames.outputs.availabilitySetNamePrefix
    availabilitySetsCount: logic.outputs.availabilitySetsCount
    availabilitySetsIndex: logic.outputs.beginAvSetRange
    availabilityZones: availabilityZones
    confidentialVMOSDiskEncryptionType: confidentialVMOSDiskEncryptionType
    cseMasterScript: cseMasterScript
    cseScriptAddDynParameters: cseScriptAddDynParameters
    cseUris: logic.outputs.cseUris
    customImageResourceId: customImageResourceId
    dataCollectionEndpointResourceId: enableMonitoring ? monitoring.outputs.dataCollectionEndpointResourceId : ''
    dedicatedHostGroupResourceId: dedicatedHostGroupResourceId
    dedicatedHostGroupZones: logic.outputs.dedicatedHostGroupZones
    dedicatedHostResourceId: dedicatedHostResourceId
    diskAccessId: deployDiskAccessResource ? management.outputs.diskAccessResourceId : ''    
    diskEncryptionSetResourceId: management.outputs.diskEncryptionSetResourceId
    diskNamePrefix: resourceNames.outputs.diskNamePrefix
    diskSizeGB: diskSizeGB
    diskSku: diskSku
    divisionRemainderValue: logic.outputs.divisionRemainderValue
    domainName: domainName
    drainMode: drainMode
    drainModeUserAssignedIdentityClientId: management.outputs.deploymentUserAssignedIdentityClientId
    enableAcceleratedNetworking: enableAcceleratedNetworking
    encryptionAtHost: encryptionAtHost
    fslogixConfigureSessionHosts: logic.outputs.fslogixConfigureSessionHosts
    fslogixContainerType: fslogixContainerType
    fslogixDeployedStorageAccountResourceIds: deployFSLogixStorage ? fslogix.outputs.storageAccountResourceIds : []
    fslogixExistingStorageAccountResourceIds: fslogixExistingStorageAccountResourceIds
    hibernationEnabled: hibernationEnabled
    hostPoolRegistrationToken: controlPlane.outputs.hostPoolRegistrationToken
    hostPoolResourceId: controlPlane.outputs.hostPoolResourceId
    identitySolution: identitySolution
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    integrityMonitoring: integrityMonitoring
    keyVaultName: resourceNames.outputs.keyVaultNames.VMs
    location: vmVirtualNetwork.location
    managementVirtualMachineName: management.outputs.virtualMachineName
    maxResourcesPerTemplateDeployment: logic.outputs.maxResourcesPerTemplateDeployment
    enableMonitoring: enableMonitoring
    networkInterfaceNamePrefix: resourceNames.outputs.networkInterfaceNamePrefix
    ouPath: ouPath
    avdInsightsDataCollectionRulesResourceId: enableMonitoring ? monitoring.outputs.avdInsightsDataCollectionRulesResourceId : ''
    vmInsightsDataCollectionRulesResourceId: enableMonitoring ? monitoring.outputs.vmInsightsDataCollectionRulesResourceId : ''
    pooledHostPool: logic.outputs.pooledHostPool
    recoveryServices: recoveryServices
    recoveryServicesVaultName: resourceNames.outputs.recoveryServicesVaultName
    resourceGroupControlPlane: empty(existingFeedWorkspaceResourceId) ? resourceNames.outputs.resourceGroupControlPlane : split(existingFeedWorkspaceResourceId, '/')[4]
    resourceGroupHosts: resourceNames.outputs.resourceGroupHosts
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    roleDefinitions: logic.outputs.roleDefinitions
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    securityPrincipals: securityPrincipals
    securityType: securityType
    secureBootEnabled: secureBootEnabled
    vTpmEnabled: vTpmEnabled
    sessionHostBatchCount: logic.outputs.sessionHostBatchCount
    sessionHostIndex: sessionHostIndex
    storageSuffix: logic.outputs.storageSuffix
    subnetResourceId: virtualMachineSubnetResourceId
    tags: deployScalingPlan ? logic.outputs.tags : tags
    timeStamp: timeStamp
    virtualMachineNamePrefix: resourceNames.outputs.virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
  }
  dependsOn: [
    rgs
  ]
}

module cleanUp 'modules/cleanUp/cleanUp.bicep' = if(!enableIncreaseQuotaAutomation) {
  name: 'CleanUp_${timeStamp}'
  params: {
    location: locationVirtualMachines
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    timeStamp: timeStamp
    userAssignedIdentityClientId: management.outputs.deploymentUserAssignedIdentityClientId
    virtualMachineName: management.outputs.virtualMachineName
  }
  dependsOn: [
    sessionHosts
  ]
}
