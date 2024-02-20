targetScope = 'subscription'

// Resource and Resource Group naming and organization
@description('Reverse the normal Cloud Adoption Framework naming convention by putting the resource type abbreviation at the end of the resource name.')
param nameConvResTypeAtEnd bool = false

@maxLength(10)
@description('''Identifier used to describe the business unit (or customer) utilizing AVD in your tenant.
If not specified then centralized AVD Management is assumed and resources and resource groups are named accordingly.
If this is specified, then the "centralizedAVDManagement" parameter determines how resources are organized and deployed.
''')
param businessUnitIdentifier string = ''

@description('''Conditional. When the "businessUnitIdentifier" parameter is not empty, this parameter determines if the AVD Monitoring Resource Group and associated resources
are created in a centralized resource group (does not include "businessUnitIdentifier" in the name) and monitoring resources are named accordingly or if a Business unit
specific AVD management resource group is created and monitoring resources are named accordingly.
If the "businessUnitIdentifier" parameter is left empty ("") then this value has no effect.
''')
param centralizedAVDMonitoring bool = false

@maxLength(10)
@description('An identifier used to distinquish each host pool. This can represent the user or use case.')
param hostPoolIdentifier string

@allowed([
  'd' // Development
  'p' // Production
  's' // Shared
  't' // Test
  '' // Not Defined
])
@description('The target environment for the solution.')
param environmentShortName string = ''

// Access to scripts and other artifacts required for this deployment

@description('Required. The name of the Azure Blobs container hosting the required artifacts.')
param artifactsContainerName string

@description('Required. The storage account resource Id where the artifacts used by this deployment are stored.')
param artifactsStorageAccountResourceId string

@description('''Optional.
The resource ID of the managed identity with Storage Blob Data Reader Access to the artifacts storage Account.
If provided this identity will be used to access blobs. Otherwise, the managed identity created
by this solution will be granted \'Storage Blob Data Reader\' rights on the storage account.
''')
param artifactsUserAssignedIdentityResourceId string = ''

@description('Optional. The name of the blob that contains the PowerShell Az Module msi.')
param azModuleBlobName string = 'PowerShell-Az.msi'

// Identity Configuration

@allowed([
  'ActiveDirectoryDomainServices' // User accounts are sourced from and Session Hosts are joined to same Active Directory domain.
  'EntraDomainServices' // User accounts are sourced from either Azure Active Directory or Active Directory Domain Services and Session Hosts are joined to Azure Active Directory Domain Services.
  'EntraId' // User accounts and Session Hosts are located in Azure Active Directory Only (Cloud Only Scenario)
  'EntraIdIntuneEnrollment' // User accounts and Session Hosts are located in Azure Active Directory Only. Session Hosts are automatically enrolled in Intune. (Cloud Only Scenario)
])
@description('The service providing domain services for Azure Virtual Desktop.  This is needed to properly configure the session hosts and if applicable, the Azure Storage Account.')
param identitySolution string

@secure()
@description('Optional. The password of the privileged account to domain join the AVD session hosts to your domain')
param domainJoinUserPassword string = ''

@secure()
@description('Optional. The UPN of the privileged account to domain join the AVD session hosts to your domain. This should be an account the resides within the domain you are joining.')
param domainJoinUserPrincipalName string = ''

@description('Optional. The name of the domain that provides ADDS to the AVD session hosts and is synchronized with Azure AD')
param domainName string = ''

@description('Optional. The distinguished name for the target Organization Unit in Active Directory Domain Services.')
param ouPath string = ''

@description('The Object ID for the Windows Virtual Desktop Enterprise Application in Azure AD.  The Object ID can found by selecting Microsoft Applications using the Application type filter in the Enterprise Applications blade of Azure AD.')
param avdObjectId string

// AVD Private Link Configuration

@description('Optional. Determines if Azure Private Link with Azure Virtual Desktop is enabled. Selecting "true" requires that private endpoints are created for the global feed, workspace feed, and hostpool.')
param avdPrivateLink bool = false

@description('Optional. Applicable when "avdPrivateLink" is "true". "Enabled" allows the global AVD feed to be accessed from both public and private networks, "Disabled" allows this resource to only be accessed via private endpoints.')
param globalWorkspacePublicNetworkAccess string = 'Enabled'

@description('Optional. Applicable when "avdPrivateLink" is "true". "Enabled" allows the AVD workspace to be accessed from both public and private networks, "Disabled" allows this resource to only be accessed via private endpoints.')
param workspacePublicNetworkAccess string = 'Enabled'

@allowed([  
  'Disabled'
  'Enabled'
  'EnabledForClientsOnly'
  'EnabledForSessionHostsOnly'
])
@description('''Optional. Applicable only when "avdPrivateLink is "true". Allow public access to the hostpool through the control plane.
"Enabled" allows this resource to be accessed from both public and private networks.
"Disabled" allows this resource to only be accessed via private endpoints.
''')
param hostPoolPublicNetworkAccess string = 'Enabled'

@description('Optional. The resource ID for the subnet for the private endpoints for AVD Private Link.')
param controlPlanePrivateEndpointSubnetResourceId string = ''

// Private Endpoints
@description('Create private endpoints for all deployed resources where applicable.')
param managementPrivateEndpoints bool = false

@description('Create private endpoints for all deployed resources where applicable.')
param storagePrivateEndpoints bool = false

@description('The Resource Id of the subnet on which to create the storage account, keyvault, and other resources private link. Required when "privateEndoints" = true.')
param managementPrivateEndpointSubnetResourceId string = ''

@description('The Resource Id of the subnet on which to create the storage account, keyvault, and other resources private link. Required when "privateEndoints" = true.')
param storagePrivateEndpointSubnetResourceId string = ''

// Private DNS Zones

@description('If using private endpoints with Automation Accounts, input the Resource ID for the Private DNS Zone linked to your hub virtual network.')
param automationAccountPrivateDnsZoneResourceId string = ''

@description('If using private endpoints with Azure files, input the Resource ID for the Private DNS Zone linked to your hub virtual network.')
param azureFilesPrivateDnsZoneResourceId string = ''

@description('If using private endpoints with Azure Virtual Desktop, input the Resource ID for the Private DNS Zone used for initial feed discovery.')
param avdGlobalFeedPrivateDnsZoneResourceId string = ''

@description('If using private endpoints with Azure Virtual Desktop, input the Resource ID for the Private DNS Zone used for feed download and connections to host pools.')
param avdPrivateDnsZoneResourceId string = ''

@description('If using private endpoints with Key Vaults, input the Resource ID for the Private DNS Zone linked to your hub virtual network.')
param keyVaultPrivateDnsZoneResourceId string = ''

// Profile Storage Configuration

@description('The custom prefix to use for the name of the Azure files storage accounts to use for FSLogix. If not specified, the name is generated automatically.')
param fslogixStorageCustomPrefix string = ''

@description('The file share size(s) in GB for the fslogix storage solution.')
param fslogixShareSizeInGB int = 100

@allowed([
  'CloudCacheProfileContainer' // FSLogix Cloud Cache Profile Container
  'CloudCacheProfileOfficeContainer' // FSLogix Cloud Cache Profile & Office Container
  'ProfileContainer' // FSLogix Profile Container
  'ProfileOfficeContainer' // FSLogix Profile & Office Container
])
param fslogixContainerType string = 'ProfileContainer'

@allowed([
  'AzureNetAppFiles Premium' // ANF with the Premium SKU, 450,000 IOPS
  'AzureNetAppFiles Standard' // ANF with the Standard SKU, 320,000 IOPS
  'AzureFiles Premium' // Azure files Premium with a Service Endpoint, 100,000 IOPs
  'AzureFiles Standard' // Azure files Standard with the Large File Share option and the default public endpoint, 20,000 IOPS
  'None'
])
@description('Enable an fslogix storage option to manage user profiles for the AVD session hosts. The selected service & SKU should provide sufficient IOPS for all of your users. https://docs.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix#performance-requirements')
param fslogixStorageService string = 'AzureFiles Standard'

@description('Optional. Enable Automatic File Share Quota Increase for Azure Files Premium.')
param enableIncreaseQuotaAutomation bool = false

@description('Configure FSLogix agent on the session hosts via local registry keys.')
param fslogixConfigureSessionHosts bool = false

@description('Optional. The name of the blob that contains the FSLogix Configuration Script.')
param fslogixConfigurationBlobName string = 'FSLogix-Configure.zip'

@description('''Existing FSLogix Storage Account Resource Ids. Only used when fslogixConfigureSessionHosts = "true".
This list will be added to any storage accounts created when setting "fslogixStorageService" to any of the AzureFiles options. 
If "identitySolution" is set to "EntraId" or "EntraIdIntuneEnrollment" then only the first storage account listed will be used.
''')
param fslogixExistingStorageAccountResourceIds array = []

@description('Optional. The resource Id of the Virtual Network delegated for NetApp Volumes. Required when fslogixStorageService = "AzureNetAppFiles Standard" or "AzureNetAppFiles Premium".')
param fslogixNetAppVnetResourceId string = ''

@allowed([
  'AES256'
  'RC4'
])
@description('The Active Directory computer object Kerberos encryption type for the Azure Storage Account or Azure NetApp files Account.')
param fslogixStorageAccountADKerberosEncryption string = 'AES256'

@maxValue(100)
@minValue(0)
@description('''
The number of storage accounts to deploy to support the required use case for the AVD stamp. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding
Note: Cannot utilize sharding with "identitySolution" = "AAD" so fslogixStorageCount will be set to 1 in variables.
''')
param fslogixStorageCount int = 1

@maxValue(99)
@minValue(0)
@description('The starting number for the storage accounts to support the required use case for the AVD stamp. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding')
param fslogixStorageIndex int = 1

// Control Plane Configuration

@description('The deployment location for the AVD management resources.')
param locationControlPlane string = deployment().location

@description('Required. The friendly name for the AVD workspace that is displayed in the client.')
param workspaceFriendlyName string = ''

@description('Optional. The friendly name for the Desktop in the AVD workspace.')
param desktopFriendlyName string = ''

@description('Enable drain mode on new sessions hosts to prevent users from accessing them until they are validated.')
param drainMode bool = false

@description('The maximum number of sessions per AVD session host.')
param hostPoolMaxSessionLimit int

@description('''Optional. Input RDP properties to add or remove RDP functionality on the AVD host pool.
Settings reference: https://learn.microsoft.com/windows-server/remote/remote-desktop-services/clients/rdp-files
''')
param hostPoolRDPProperties string = 'audiocapturemode:i:1;camerastoredirect:s:*'

@allowed([
  'Pooled DepthFirst'
  'Pooled BreadthFirst'
  'Personal Automatic'
  'Personal Direct'
])
@description('These options specify the host pool type and depending on the type provides the load balancing options and assignment types.')
param hostPoolType string = 'Pooled DepthFirst'

@description('The value determines whether the hostPool should receive early AVD updates for testing.')
param hostPoolValidationEnvironment bool = false

@description('An array of Security Principals with their object IDs and display names to assign to the AVD Application Group and FSLogix Storage.')
param securityPrincipals array = []

@maxValue(5000)
@minValue(0)
@description('The number of session hosts to deploy in the host pool. Ensure you have the approved quota to deploy the desired count.')
param sessionHostCount int = 1

@maxValue(4999)
@minValue(0)
@description('The starting number for the session hosts. This is important when adding virtual machines to ensure an update deployment is not performed on an exiting, active session host.')
param sessionHostIndex int = 1

// Session Host/VM Configuration

@allowed([
  'availabilitySets'
  'availabilityZones'
  'None'
])
@description('Set the desired availability / SLA with a pooled host pool.  The best practice is to deploy to availability Zones for resilency.')
param availability string = 'availabilityZones'

@description('Optional. The name of the blob containing the AVDAgent Agent installers and script.')
param avdAgentInstallersBlobName string = 'Set-SessionHostConfiguration.zip'


@description('''Array of script (or other artifact) names or full uris that will be downloaded by the Custom Script Extension on each Session Host Virtual Machine.
Either specify the entire URL or just the name of the blob if is located at the fqdn specified by the [artifactsUri] parameter.
''')
param cseBlobNames array = []

@description('Optional. The name of the script and blob that is ran by the Custom Script Extension on Virtual Machines.')
param cseMasterScript string = 'cse_master_script.ps1'

@description('''Additional Custom Dynamic parameters passed to CSE Scripts.
(ex: 'Script2Keys=@([pscustomobject]@{stringValue=\'storageAccountName\';booleanValue=\'false\'});Script3Keys=@([pscustomobject]@{intValue=\'10\'}')
''')
param cseScriptAddDynParameters string = ''

@description('''Optional. Encryption at host encrypts temporary disks and ephemeral OS disks with platform-managed keys,
OS and data disk caches with the key specified in the "keyManagementDisksAndStorage" parameter, and flows encrypted to the Storage service.
''')
param encryptionAtHost bool = true

@description('Optional. Confidential disk encryption is an additional layer of encryption which binds the disk encryption keys to the virtual machine TPM and makes the disk content accessible only to the VM.')
param confidentialVMOSDiskEncryption bool = false

@description('''Optional. The object ID of the Confidential VM Orchestrator enterprise application with application ID "bf7b6499-ff71-4aa2-97a4-f372087be7f0".
This is required when "confidentialVMOSDiskEncryption" is set to "true". You must create this application in your tenant before deploying this solution using the following PowerShell script:
  Connect-AzureAD -Tenant "your tenant ID"
  New-AzureADServicePrincipal -AppId bf7b6499-ff71-4aa2-97a4-f372087be7f0 -DisplayName "Confidential VM Orchestrator"
''')
param confidentialVMOrchestratorObjectId string = ''

@allowed([
  'CustomerManaged'
  'PlatformManaged'
  'PlatformManagedAndCustomerManaged'
])
@description('''Optional. The type of encryption key management used for the OS disk. (Default: "PlatformManaged")
- Platform-managed keys (PMKs) are key encryption keys that are generated, stored, and managed entirely by Azure. Choose Platform Managed for the best balance of security and ease of use.
- Customer-managed keys (CMKs) are key encryption keys that are generated, stored, and managed by you, the customer, in your Azure Key Vault. Choose Customer Managed if you need to meet specific compliance requirements.
- Double encryption is 2 layers of encryption: an infrastructure encryption layer with platform managed keys and a disk encryption layer with customer managed keys defined by disk encryption sets.
Choose Platform Managed and Customer Managed if you need double encryption. This option does not apply to confidential VMs.
''')
param keyManagementDisksAndStorage string = 'PlatformManaged'

@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
@description('The storage SKU for the AVD session host disks.  Production deployments should use Premium_LRS.')
param diskSku string = 'Premium_LRS'

@allowed([
  'Standard'
  'ConfidentialVM'
  'TrustedLaunch'
])
@description('Optional. The Security Type of the AVD Session Hosts.  ConfidentialVM and TrustedLaunch are only available in certain regions.')
param virtualMachineSecurityType string = 'TrustedLaunch'

@description('Offer for the virtual machine image')
param imageOffer string = 'office-365'

@description('Publisher for the virtual machine image')
param imagePublisher string = 'MicrosoftWindowsDesktop'

@description('SKU for the virtual machine image')
param imageSku string = 'win11-23h2-avd-m365'

@description('The resource ID for the Compute Gallery Image Version. Do not set this value if using a marketplace image.')
param customImageResourceId string = ''

@description('The resource ID of the subnet to place the network interfaces for the AVD session hosts.')
param virtualMachineSubnetResourceId string

@secure()
@description('Local administrator password for the AVD session hosts')
param virtualMachineAdminPassword string

@secure()
@description('The Local Administrator Username for the Session Hosts')
param virtualMachineAdminUserName string

@description('The VM SKU for the AVD session hosts.')
param virtualMachineSize string = 'Standard_D4ads_v5'

@minLength(2)
@maxLength(12)
@description('The Virtual Machine Name prefix.')
param virtualMachineNamePrefix string

// Monitoring Configuration
@description('Deploys the required monitoring resources to enable AVD Insights and monitor features in the automation account.')
param enableInsights bool = true

@maxValue(730)
@minValue(30)
@description('The retention for the Log Analytics Workspace to setup the AVD monitoring solution')
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
@description('The SKU for the Log Analytics Workspace to setup the AVD monitoring solution')
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('The resource ID of the log analytics workspace used for Azure Sentinel and / or Defender for Cloud. When using the Microsoft Monitor Agent (Log Analytics Agent), this allows you to multihome the agent to reduce unnecessary log collection and reduce cost.')
param securityLogAnalyticsWorkspaceResourceId string = ''

@description('The resource ID of the data collection rule used for Azure Sentinel and / or Defender for Cloud when using the Azure Monitor Agent.')
param securityDataCollectionRulesResourceId string = ''

// Backup Configuration

@description('Enable backups to an Azure Recovery Services vault.  For a pooled host pool this will enable backups on the Azure file share.  For a personal host pool this will enable backups on the AVD sessions hosts.')
param recoveryServices bool = false

// Tags
@description('Key / value pairs of metadata for the Azure resource groups and resources.')
param tags object = {}

@description('DO NOT MODIFY THIS VALUE! The timeStamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param timeStamp string = utcNow('yyyyMMddhhmmss')

var artifactsStorageAccountName = last(split(artifactsStorageAccountResourceId, '/'))
var artifactsUri = 'https://${artifactsStorageAccountName}.blob.${environment().suffixes.storage}/${artifactsContainerName}/'
var locationVirtualMachines = vmVirtualNetwork.location
var confidentialVMOSDiskEncryptionType = confidentialVMOSDiskEncryption ? 'DiskWithVMGuestState' : 'VMGuestStateOnly'

var resourceGroupsCount = 4 + (fslogixStorageService == 'None' ? 0 : 1) + (avdPrivateLink ? 1 :0)

var securityType = virtualMachineSecurityType == 'Standard' ? '' : virtualMachineSecurityType

// Existing Virtual Network location
resource vmVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: split(virtualMachineSubnetResourceId, '/')[8]
  scope: resourceGroup(split(virtualMachineSubnetResourceId, '/')[2], split(virtualMachineSubnetResourceId, '/')[4])
}

resource keyVault_Reference 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = if(contains(identitySolution,'DomainServices') && (empty(domainJoinUserPassword) || empty(domainJoinUserPrincipalName)) || empty(virtualMachineAdminPassword) || empty(virtualMachineAdminUserName))  {
  name: resourceNames.outputs.keyVaultNames.VMSecrets
  scope: resourceGroup(resourceNames.outputs.resourceGroupManagement)
}

// Resource Names
module resourceNames 'modules/resourceNames.bicep' = {
  name: 'ResourceNames_${timeStamp}'
  params: {
    environmentShortName: environmentShortName
    businessUnitIdentifier: businessUnitIdentifier
    centralizedAVDMonitoring: centralizedAVDMonitoring
    fslogixStorageCustomPrefix: fslogixStorageCustomPrefix
    hostPoolIdentifier: hostPoolIdentifier
    locationControlPlane: locationControlPlane
    locationVirtualMachines: locationVirtualMachines
    nameConvResTypeAtEnd: nameConvResTypeAtEnd
    virtualMachineNamePrefix: virtualMachineNamePrefix
  }
}

// Logic
module logic 'modules/logic.bicep' = {
  name: 'Logic_${timeStamp}'
  params: {
    artifactsUri: artifactsUri
    avdAgentInstallersBlobName: avdAgentInstallersBlobName
    avdPrivateLink: avdPrivateLink
    cseMasterScript: cseMasterScript
    diskSku: diskSku
    cseBlobNames: cseBlobNames
    domainName: domainName
    fileShareNames: resourceNames.outputs.fileShareNames
    fslogixConfigureSessionHosts: fslogixConfigureSessionHosts
    fslogixConfigurationBlobName: fslogixConfigurationBlobName
    fslogixContainerType: fslogixContainerType
    fslogixStorageService: fslogixStorageService
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
    securityPrincipals: securityPrincipals
    sessionHostCount: sessionHostCount
    sessionHostIndex: sessionHostIndex
    fslogixStorageCount: fslogixStorageCount
    virtualMachineNamePrefix: resourceNames.outputs.virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
  }
}

// Resource Groups
module rgs 'modules/resourceGroups.bicep' = [for i in range(0, resourceGroupsCount): {
  name: 'ResourceGroup_${i}_${timeStamp}'
  params: {
    location: contains(logic.outputs.resourceGroupNames[i], 'controlPlane') || contains(logic.outputs.resourceGroupNames[i], 'global-feed') ? locationControlPlane : locationVirtualMachines
    resourceGroupName: logic.outputs.resourceGroupNames[i]
    tags: tags
  }
}]

// Management Services: Logging, Automation, Keys, Encryption
module management 'modules/management/management.bicep' = {
  name: 'Management_${timeStamp}'
  params: {
    artifactsUri: artifactsUri
    artifactsStorageAccountResourceId: artifactsStorageAccountResourceId
    artifactsUserAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
    automationAccountName: resourceNames.outputs.automationAccountName
    automationAccountPrivateDnsZoneResourceId: automationAccountPrivateDnsZoneResourceId
    availability: availability
    avdObjectId: avdObjectId
    azModuleBlobName: azModuleBlobName
    confidentialVMOrchestratorObjectId: confidentialVMOrchestratorObjectId
    confidentialVMOSDiskEncryptionType: confidentialVMOSDiskEncryptionType
    //diskAccessName: resourceNames.outputs.diskAccessName
    diskEncryptionSetNames: resourceNames.outputs.diskEncryptionSetNames
    diskSku: diskSku
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainName: domainName
    enableIncreaseQuotaAutomation: enableIncreaseQuotaAutomation
    encryptionAtHost: encryptionAtHost
    environmentShortName: environmentShortName
    fslogix: logic.outputs.fslogix
    fslogixStorageAccountNamePrefix: resourceNames.outputs.storageAccountNamePrefix
    fslogixStorageService: fslogixStorageService
    hostPoolType: hostPoolType
    identitySolution: identitySolution
    kerberosEncryption: fslogixStorageAccountADKerberosEncryption
    keyVaultNames: resourceNames.outputs.keyVaultNames
    keyVaultPrivateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
    locationControlPlane: locationControlPlane
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    enableInsights: enableInsights
    netAppVnetResourceId: fslogixNetAppVnetResourceId
    keyManagementDisksAndStorage: keyManagementDisksAndStorage
    privateEndpointSubnetResourceId: managementPrivateEndpointSubnetResourceId
    privateEndpoint: managementPrivateEndpoints
    privateEndpointNameConv: resourceNames.outputs.privateEndpointNameConv
    recoveryServices: recoveryServices
    recoveryServicesVaultName: resourceNames.outputs.recoveryServicesVaultName
    resourceGroupHosts: resourceNames.outputs.resourceGroupHosts
    resourceGroupControlPlane: resourceNames.outputs.resourceGroupControlPlane
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    resourceGroupStorage: resourceNames.outputs.resourceGroupStorage
    roleDefinitions: logic.outputs.roleDefinitions
    securityType: securityType
    sessionHostCount: sessionHostCount
    fslogixStorageSolution: logic.outputs.fslogixStorageSolution
    tags: tags
    timeStamp: timeStamp
    timeZone: logic.outputs.timeZone
    userAssignedIdentityNameConv: resourceNames.outputs.userAssignedIdentityNameConv
    virtualMachineName: resourceNames.outputs.mgmtVirtualMachineName
    virtualMachineNICName: resourceNames.outputs.mgmtVirtualMachineNicName
    virtualMachineDiskName: resourceNames.outputs.mgmtVirtualMachineDiskName
    virtualMachineAdminPassword: empty(virtualMachineAdminPassword) ? keyVault_Reference.getSecret(virtualMachineAdminPassword) : virtualMachineAdminPassword
    virtualMachineSize: virtualMachineSize
    virtualMachineAdminUserName: empty(virtualMachineAdminUserName) ? keyVault_Reference.getSecret(virtualMachineAdminUserName) : virtualMachineAdminUserName
    virtualMachineSubnetResourceId: virtualMachineSubnetResourceId
    workspaceName: resourceNames.outputs.workspaceName
    globalFeedWorkspaceName: resourceNames.outputs.globalFeedWorkspaceName
    globalFeedWorkspaceResourceGroupName: resourceNames.outputs.resourceGroupGlobalFeed
  }                
  dependsOn: [
    rgs
  ]
}

module monitoring 'modules/monitoring/monitoring.bicep' = if(enableInsights) {
  name: 'Monitoring_${timeStamp}'
  params: {
    dataCollectionEndpointName: resourceNames.outputs.dataCollectionEndpointName
    dataCollectionRulesNameConv: resourceNames.outputs.dataCollectionRulesNameConv
    location: locationVirtualMachines
    logAnalyticsWorkspaceName: resourceNames.outputs.logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRetention:logAnalyticsWorkspaceRetention
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    resourceGroupMonitoring: resourceNames.outputs.resourceGroupMonitoring
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    tags: tags
    timeStamp: timeStamp
  }
  dependsOn: [
    rgs
  ]
}

// AVD Control Plane Resources
// This module deploys the host pool and desktop application group
module controlPlane 'modules/controlPlane/controlPlane.bicep' = {
  name: 'ControlPlane_${timeStamp}'
  params: {
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: management.outputs.artifactsUserAssignedIdentityClientId
    avdGlobalFeedPrivateDnsZoneResourceId: avdGlobalFeedPrivateDnsZoneResourceId
    avdPrivateDnsZoneResourceId: avdPrivateDnsZoneResourceId
    avdPrivateLink: avdPrivateLink
    deploymentUserAssignedIdentityClientId: management.outputs.deploymentUserAssignedIdentityClientId
    desktopApplicationGroupName: resourceNames.outputs.desktopApplicationGroupName
    desktopFriendlyName: desktopFriendlyName
    existingGlobalWorkspace: management.outputs.existingGlobalWorkspace
    existingWorkspace: management.outputs.existingWorkspace
    globalWorkspaceName: resourceNames.outputs.globalFeedWorkspaceName
    globalWorkspacePublicNetworkAccess: globalWorkspacePublicNetworkAccess
    hostPoolMaxSessionLimit: hostPoolMaxSessionLimit
    hostPoolName: resourceNames.outputs.hostPoolName
    hostPoolPublicNetworkAccess: hostPoolPublicNetworkAccess
    hostPoolRDPProperties: hostPoolRDPProperties
    hostPoolType: hostPoolType
    hostPoolValidationEnvironment: hostPoolValidationEnvironment
    identitySolution: identitySolution
    locationControlPlane: locationControlPlane
    locationVirtualMachines: locationVirtualMachines
    logAnalyticsWorkspaceResourceId: enableInsights ? monitoring.outputs.logAnalyticsWorkspaceResourceId : ''
    managementVirtualMachineName: management.outputs.virtualMachineName    
    enableInsights: enableInsights
    privateEndpointNameConv: resourceNames.outputs.privateEndpointNameConv
    privateEndpointSubnetResourceId: controlPlanePrivateEndpointSubnetResourceId
    resourceGroupControlPlane: resourceNames.outputs.resourceGroupControlPlane
    resourceGroupGlobalFeed: resourceNames.outputs.resourceGroupGlobalFeed
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    roleDefinitions: logic.outputs.roleDefinitions
    securityPrincipalObjectIds: map(securityPrincipals, item => item.objectId)
    tags: tags
    timeStamp: timeStamp
    virtualMachineTemplate: logic.outputs.virtualMachineTemplate
    workspaceFriendlyName: workspaceFriendlyName
    workspaceName: resourceNames.outputs.workspaceName
    workspacePublicNetworkAccess: workspacePublicNetworkAccess
  }
  dependsOn: [
    rgs
  ]
}

module fslogix 'modules/fslogix/fslogix.bicep' = if (fslogixStorageService != 'None') {
  name: 'FSLogix_${timeStamp}'
  params: {
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: management.outputs.artifactsUserAssignedIdentityClientId
    activeDirectoryConnection: management.outputs.validateANFfActiveDirectory
    automationAccountName: resourceNames.outputs.automationAccountName
    availability: availability
    azureFilesPrivateDnsZoneResourceId: azureFilesPrivateDnsZoneResourceId
    customerManagedKeysEnabled: keyManagementDisksAndStorage != 'PlatformManaged' ? true : false
    deploymentUserAssignedIdentityClientId: management.outputs.deploymentUserAssignedIdentityClientId
    delegatedSubnetId: management.outputs.validateANFSubnetId
    dnsServers: management.outputs.validateANFDnsServers
    domainJoinUserPassword: empty(domainJoinUserPassword) ? contains(identitySolution, 'DomainServices') ? keyVault_Reference.getSecret(domainJoinUserPassword) : '' : domainJoinUserPassword
    domainJoinUserPrincipalName: empty(domainJoinUserPrincipalName) ? contains(identitySolution, 'DomainServices') ? keyVault_Reference.getSecret(domainJoinUserPrincipalName) : '' : domainJoinUserPrincipalName
    domainName: domainName
    enableIncreaseQuotaAutomation: enableIncreaseQuotaAutomation
    encryptionUserAssignedIdentityResourceId: management.outputs.encryptionUserAssignedIdentityResourceId
    fileShares: logic.outputs.fileShares
    shareSizeInGB: fslogixShareSizeInGB
    containerType: fslogixContainerType
    storageService: fslogixStorageService
    identitySolution: identitySolution
    kerberosEncryption: fslogixStorageAccountADKerberosEncryption
    keyVaultUri: management.outputs.storageEncryptionKeyKeyVaultUri
    location: locationVirtualMachines
    managementVirtualMachineName: management.outputs.virtualMachineName
    netAppAccountName: resourceNames.outputs.netAppAccountName
    netAppCapacityPoolName: resourceNames.outputs.netAppCapacityPoolName
    netbios: logic.outputs.netbios
    ouPath: ouPath
    privateEndpoint: storagePrivateEndpoints
    privateEndpointNameConv: resourceNames.outputs.privateEndpointNameConv
    recoveryServices: recoveryServices
    recoveryServicesVaultName: resourceNames.outputs.recoveryServicesVaultName
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    resourceGroupStorage: resourceNames.outputs.resourceGroupStorage
    securityPrincipalObjectIds: map(securityPrincipals, item => item.objectId)
    securityPrincipalNames: map(securityPrincipals, item => item.name)
    smbServerLocation: logic.outputs.smbServerLocation
    storageAccountNamePrefix: resourceNames.outputs.storageAccountNamePrefix
    storageCount: logic.outputs.fslogixStorageCount
    storageEncryptionKeyName: management.outputs.storageAccountEncryptionKeyName
    storageIndex: fslogixStorageIndex
    storageSku: logic.outputs.fslogixStorageSku
    storageSolution: logic.outputs.fslogixStorageSolution
    subnet: split(storagePrivateEndpointSubnetResourceId, '/')[10]
    tagsAutomationAccounts: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/workspaces/${resourceNames.outputs.workspaceName}'
      }, contains(tags, 'Microsoft.Automation/automationAccounts') ? tags['Microsoft.Automation/automationAccounts'] : {})
    tagsNetAppAccount: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostPools/${resourceNames.outputs.hostPoolName}'
      }, contains(tags, 'Microsoft.NetApp/netAppAccounts') ? tags['Microsoft.NetApp/netAppAccounts'] : {})
    tagsPrivateEndpoints: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostPools/${resourceNames.outputs.hostPoolName}'
      }, contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {})
    tagsStorageAccounts: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostPools/${resourceNames.outputs.hostPoolName}'
      }, contains(tags, 'Microsoft.Storage/storageAccounts') ? tags['Microsoft.Storage/storageAccounts'] : {})
    tagsRecoveryServicesVault: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostPools/${resourceNames.outputs.hostPoolName}'
      }, contains(tags, 'Microsoft.recoveryServices/vaults') ? tags['Microsoft.recoveryServices/vaults'] : {})
    tagsVirtualMachines: union({
        'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceNames.outputs.resourceGroupManagement}/providers/Microsoft.DesktopVirtualization/hostPools/${resourceNames.outputs.hostPoolName}'
      }, contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {})
    timeStamp: timeStamp
    timeZone: logic.outputs.timeZone
    virtualNetwork: split(storagePrivateEndpointSubnetResourceId, '/')[8]
    virtualNetworkResourceGroup: split(storagePrivateEndpointSubnetResourceId, '/')[4]
  }
  dependsOn: [
    controlPlane
  ]
}

module sessionHosts 'modules/sessionHosts/sessionHosts.bicep' = {
  name: 'SessionHosts_${timeStamp}'
  params: {
    acceleratedNetworking: management.outputs.validateAcceleratedNetworking
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: management.outputs.artifactsUserAssignedIdentityClientId // ClientId that comes from Management / UserAssignedIdentity Modules is already determined.
    artifactsUserAssignedIdentityResourceId: management.outputs.artifactsUserAssignedIdentityResourceId // ResourceId that comes from Management / UserAssignedIdentity Modules is already determined.
    availability: availability
    availabilitySetNamePrefix: resourceNames.outputs.availabilitySetNamePrefix
    availabilitySetsCount: logic.outputs.availabilitySetsCount
    availabilitySetsIndex: logic.outputs.beginAvSetRange
    availabilityZones: management.outputs.validateavailabilityZones
    confidentialVMOSDiskEncryptionType: confidentialVMOSDiskEncryptionType
    cseMasterScript: cseMasterScript
    cseScriptAddDynParameters: cseScriptAddDynParameters
    cseUris: logic.outputs.cseUris
    customImageResourceId: customImageResourceId
    dataCollectionEndpointResourceId: monitoring.outputs.dataCollectionEndpointResourceId    
    diskEncryptionSetResourceId: management.outputs.diskEncryptionSetResourceId
    diskNamePrefix: resourceNames.outputs.diskNamePrefix
    diskSku: diskSku
    divisionRemainderValue: logic.outputs.divisionRemainderValue
    domainJoinUserPassword: empty(domainJoinUserPassword) ? contains(identitySolution, 'DomainServices') ? keyVault_Reference.getSecret(domainJoinUserPassword) : '' : domainJoinUserPassword
    domainJoinUserPrincipalName: empty(domainJoinUserPrincipalName) ? contains(identitySolution, 'DomainServices') ? keyVault_Reference.getSecret(domainJoinUserPrincipalName) : '' : domainJoinUserPrincipalName
    domainName: domainName
    drainMode: drainMode
    drainModeUserAssignedIdentityClientId: management.outputs.deploymentUserAssignedIdentityClientId
    encryptionAtHost: encryptionAtHost
    fslogixConfigureSessionHosts: logic.outputs.fslogixConfigureSessionHosts
    fslogixContainerType: fslogixContainerType
    fslogixDeployedStorageAccountResourceIds: (fslogixStorageService != 'None') ? fslogix.outputs.storageAccountResourceIds : []
    fslogixExistingStorageAccountResourceIds: fslogixExistingStorageAccountResourceIds
    hostPoolName: controlPlane.outputs.hostPoolName
    identitySolution: identitySolution
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    location: vmVirtualNetwork.location
    managementVirtualMachineName: management.outputs.virtualMachineName
    maxResourcesPerTemplateDeployment: logic.outputs.maxResourcesPerTemplateDeployment
    enableInsights: enableInsights
    networkInterfaceNamePrefix: resourceNames.outputs.networkInterfaceNamePrefix
    ouPath: ouPath
    avdInsightsDataCollectionRulesResourceId: monitoring.outputs.avdInsightsDataCollectionRulesResourceId
    vmInsightsDataCollectionRulesResourceId: monitoring.outputs.vmInsightsDataCollectionRulesResourceId
    pooledHostPool: logic.outputs.pooledHostPool
    recoveryServices: recoveryServices
    recoveryServicesVaultName: resourceNames.outputs.recoveryServicesVaultName
    resourceGroupControlPlane: resourceNames.outputs.resourceGroupControlPlane
    resourceGroupHosts: resourceNames.outputs.resourceGroupHosts
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    roleDefinitions: logic.outputs.roleDefinitions
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    securityPrincipalObjectIds: map(securityPrincipals, item => item.objectId)
    securityLogAnalyticsWorkspaceResourceId: securityLogAnalyticsWorkspaceResourceId
    securityType: securityType
    sessionHostBatchCount: logic.outputs.sessionHostBatchCount
    sessionHostIndex: sessionHostIndex
    storageSuffix: logic.outputs.storageSuffix
    subnetResourceId: virtualMachineSubnetResourceId
    tags: tags
    timeStamp: timeStamp
    virtualMachineNamePrefix: resourceNames.outputs.virtualMachineNamePrefix
    virtualMachineAdminPassword: empty(virtualMachineAdminPassword) ? keyVault_Reference.getSecret(virtualMachineAdminPassword) : virtualMachineAdminPassword
    virtualMachineSize: virtualMachineSize
    virtualMachineAdminUserName: empty(virtualMachineAdminUserName) ? keyVault_Reference.getSecret(virtualMachineAdminUserName) : virtualMachineAdminUserName 
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
