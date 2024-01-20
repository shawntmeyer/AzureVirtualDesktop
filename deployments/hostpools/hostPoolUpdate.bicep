targetScope = 'subscription'

// Resource and Resource Group naming and organization

@description('Reverse the normal Cloud Adoption Framework naming convention by putting the resource type abbreviation at the end of the resource name.')
param nameConvResTypeAtEnd bool = false

@description('The resource ID of the AVD hostpool to update.')
param hostPoolResourceId string

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

// Identity Configuration

@allowed([
  'ActiveDirectoryDomainServices' // User accounts are sourced from and Session Hosts are joined to same Active Directory domain.
  'AzureActiveDirectoryDomainServices' // User accounts are sourced from either Azure Active Directory or Active Directory Domain Services and Session Hosts are joined to Azure Active Directory Domain Services.
  'AzureActiveDirectory' // User accounts and Session Hosts are located in Azure Active Directory Only (Cloud Only Scenario)
  'AzureActiveDirectoryIntuneEnrollment' // User accounts and Session Hosts are located in Azure Active Directory Only. Session Hosts are automatically enrolled in Intune. (Cloud Only Scenario)
  'AzureActiveDirectoryAndKerberos' // User accounts are sourced from Active Directory domain and session hosts are joined to Azure Active Directory natively.
  'AzureActiveDirectoryAndKerberosIntuneEnrollment' // User accounts are sourced from Active Directory domain and session hosts are joined to Azure Active Directory natively with Intune Enrollment.
])
@description('The service providing domain services for Azure Virtual Desktop.  This is needed to properly configure the session hosts and if applicable, the Azure Storage Account.')
param activeDirectorySolution string

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

// Profile Storage Configuration

@allowed([
  'CloudCacheProfileContainer' // FSLogix Cloud Cache Profile Container
  'CloudCacheProfileOfficeContainer' // FSLogix Cloud Cache Profile & Office Container
  'ProfileContainer' // FSLogix Profile Container
  'ProfileOfficeContainer' // FSLogix Profile & Office Container
])
param fslogixContainerType string = 'ProfileContainer'

@description('''Optional. The UNC paths for NetApp File Shares that support FSLogix.
Only required when "fslogixConfigureSessionHosts" is true and "fslogixStorageService" is AzureNetAppFiles Premium or Standard.
If an office container path is specified, then ensure that the profile path is first.
Do NOT include the trailing "\".''')
param fslogixNetAppFileShares array = ['None']

@allowed([
  'AzureNetAppFiles Premium' // ANF with the Premium SKU, 450,000 IOPS
  'AzureNetAppFiles Standard' // ANF with the Standard SKU, 320,000 IOPS
  'AzureFiles Premium' // Azure files Premium with a Service Endpoint, 100,000 IOPs
  'AzureFiles Standard' // Azure files Standard with the Large File Share option and the default public endpoint, 20,000 IOPS
  'None'
])
@description('''Enable an fslogix storage option to manage user profiles for the AVD session hosts. The selected service & SKU should provide sufficient IOPS for all of your users.
https://docs.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix#performance-requirements''')
param fslogixStorageService string = 'AzureFiles Standard'

@description('Configure FSLogix agent on the session hosts via local registry keys.')
param fslogixConfigureSessionHosts bool = true

@description('Optional. The name of the blob that contains the FSLogix Configuration Script.')
param fslogixConfigurationBlobName string = 'FSLogix-Configure.zip'

@description('''Existing FSLogix Storage Account Resource Ids. Only used when fslogixConfigureSessionHosts = "true".
This list will be added to any storage accounts created when setting "fslogixStorageService" to any of the AzureFiles options. 
If "activeDirectorySolution" is set to "AzureActiveDirectory" or "AzureActiveDirectoryIntuneEnrollment" then only the first storage account listed will be used.
''')
param fslogixExistingStorageAccountResourceIds array = []

@maxValue(100)
@minValue(0)
@description('''
The number of storage accounts to deploy to support the required use case for the AVD stamp. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding
Note: Cannot utilize sharding with "activeDirectorySolution" = "AAD" so storageCount will be set to 1 in variables.
''')
param storageCount int = 1

// Control Plane Configuration

@allowed([
  'Pooled DepthFirst'
  'Pooled BreadthFirst'
  'Personal Automatic'
  'Personal Direct'
])
@description('These options specify the host pool type and depending on the type provides the load balancing options and assignment types.')
param hostPoolType string = 'Pooled DepthFirst'

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
  'True'
  'False'
])
@description('Enable accelerated networking on the AVD session hosts.')
param acceleratedNetworking string = 'True'

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

@allowed([
  'SSE + PMK' // Default Encryption in Azure
  'SSE + CMK' // Server Side Encryption with Customer Managed Keys
  'EAH + PMK' // Encryption at Host with Platform Managed Keys
  'EAH + CMK' // Encryption at Host with Customer Managed Keys
  'ADE' // Azure Disk Encryption
  'ADE + KEK' // Azure Disk Encryption with Key Encryption Key
])
@description('Optional. The VM disk encryption configuration. (Default: "SSE + PMK")')
param diskEncryptionSolution string = 'SSE + PMK'

@description('Optional. The resource ID of the Azure Disk Encryption Set to use to protect the ADE encryption keys. Only valid when diskEncryptionSolution specifies customer managed keys.')
param diskEncryptionSetResourceId string = ''

@description('Optional. The resource ID of the Azure Key Vault used to store the ADE encryption keys. Only valid when diskEncryptionSolution specifies Azure Disk Encryption.')
param adeKeyVaultResourceId string = ''

@description('Optional. The resource ID of the Azure Disk Encryption Key to use to protect the ADE encryption keys. Only valid when diskEncryptionSolution = "ADE + KEK"')
param adeKeyEncryptionKeyResourceId string = ''

@allowed([
  'true'
  'false'
])
@description('Optional. Enable Trusted Launch on the AVD session hosts.  This requires the host pool to be deployed in a region that supports Trusted Launch.  https://docs.microsoft.com/en-us/azure/virtual-desktop/trusted-launch.')
param trustedLaunch string = 'true'

@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
@description('The storage SKU for the AVD session host disks.  Production deployments should use Premium_LRS.')
param diskSku string = 'Premium_LRS'

@description('Offer for the virtual machine image')
param imageOffer string = 'office-365'

@description('Publisher for the virtual machine image')
param imagePublisher string = 'MicrosoftWindowsDesktop'

@description('SKU for the virtual machine image')
param imageSku string = 'win11-22h2-avd-m365'

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

@maxLength(12)
@description('Required. The Virtual Machine Name prefix.')
param virtualMachineNamePrefix string

// Monitoring Configuration
@description('Deploys the required monitoring resources to enable AVD Insights and monitor features in the automation account.')
param monitoring bool = true

@description('Optional. The resource ID of the Data Collection Endpoint used for performance data with Azure Monitor.')
param perfDataCollectionEndpointResourceId string = ''

@description('Optional. The resource IDs of the Data Collection Rules used for performance data with Azure Monitor.')
param perfDataCollectionRulesResourceIds array = []

@description('The resource ID of the log analytics workspace used for performance data with Azure Monitor.')
param perfLogAnalyticsWorkspaceResourceId string = ''

@description('The resource ID of the log analytics workspace used for Azure Sentinel and / or Defender for Cloud. When using the Microsoft Monitor Agent (Log Analytics Agent), this allows you to multihome the agent to reduce unnecessary log collection and reduce cost.')
param securityLogAnalyticsWorkspaceResourceId string = ''

@description('The resource ID of the data collection endpoint used for Azure Sentinel and / or Defender for Cloud. When using the Azure Monitor Agent, this allows you to multihome the agent to reduce unnecessary log collection and reduce cost.')
param securityDataCollectionEndpointResourceId string = ''

@description('The resource ID of the data collection rule used for Azure Sentinel and / or Defender for Cloud when using the Azure Monitor Agent.')
param securityDataCollectionRulesResourceId string = ''

@allowed([
  'AzureMonitorAgent'
  'LogAnalyticsAgent'
])
@description('Input the desired monitoring agent to send security data to the log analytics workspace.')
param performanceMonitoringAgent string = 'AzureMonitorAgent'

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
var availabilityZones = availability == 'availabilityZones' ? [
  '1'
  '2'
  '3'
] : []
var locationVirtualMachines = vmVirtualNetwork.location
var resourceGroupControlPlane = split(hostPoolResourceId, '/')[4]
var hostPoolName = last(split(hostPoolResourceId, '/'))

resource artifactsUAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: last(split(artifactsUserAssignedIdentityResourceId, '/'))
  scope: resourceGroup(split(artifactsUserAssignedIdentityResourceId, '/')[2], split(artifactsUserAssignedIdentityResourceId, '/')[4])
}

resource vmVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: split(virtualMachineSubnetResourceId, '/')[8]
  scope: resourceGroup(split(virtualMachineSubnetResourceId, '/')[2], split(virtualMachineSubnetResourceId, '/')[4])
}

resource keyVault_Reference 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = if(contains(activeDirectorySolution,'DomainServices') && (empty(domainJoinUserPassword) || empty(domainJoinUserPrincipalName)) || empty(virtualMachineAdminPassword) || empty(virtualMachineAdminUserName))  {
  name: resourceNames.outputs.keyVaultName
  scope: resourceGroup(resourceNames.outputs.resourceGroupManagement)
}

resource adeKeyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = if(!empty(adeKeyVaultResourceId)) {
  name: last(split(adeKeyVaultResourceId, '/'))
  scope: resourceGroup(split(adeKeyVaultResourceId, '/')[2], split(adeKeyVaultResourceId, '/')[4])
}

resource adeKeyEncryptionKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' existing = if(diskEncryptionSolution == 'ADE + KEK') {
  name: last(split(adeKeyEncryptionKeyResourceId, '/'))
  scope: resourceGroup(split(adeKeyEncryptionKeyResourceId, '/')[4], split(adeKeyEncryptionKeyResourceId, '/')[8])
}

// Resource Names
module resourceNames 'modules/resourceNames.bicep' = {
  name: 'ResourceNames_${timeStamp}'
  params: {
    environmentShortName: environmentShortName
    businessUnitIdentifier: ''
    centralizedAVDManagement: false
    fslogixStorageCustomPrefix: ''
    hostPoolIdentifier: ''
    locationControlPlane: locationVirtualMachines
    locationVirtualMachines: locationVirtualMachines
    nameConvResTypeAtEnd: nameConvResTypeAtEnd
    virtualMachineNamePrefix: virtualMachineNamePrefix
  }
}

// Logic
module logic 'modules/logic.bicep' = {
  name: 'Logic_${timeStamp}'
  params: {
    activeDirectorySolution: activeDirectorySolution
    artifactsUri: artifactsUri
    avdAgentInstallersBlobName: avdAgentInstallersBlobName
    avdPrivateLink: false
    cseMasterScript: cseMasterScript
    diskEncryptionSolution: diskEncryptionSolution
    diskSku: diskSku
    cseBlobNames: cseBlobNames
    domainName: domainName
    fileShareNames: resourceNames.outputs.fileShareNames
    fslogixConfigureSessionHosts: fslogixConfigureSessionHosts
    fslogixConfigurationBlobName: fslogixConfigurationBlobName
    fslogixContainerType: fslogixContainerType
    fslogixStorageService: fslogixStorageService
    hostPoolType: hostPoolType
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    locations: resourceNames.outputs.locations
    locationVirtualMachines: locationVirtualMachines
    resourceGroupControlPlane: resourceGroupControlPlane
    resourceGroupGlobalFeed: resourceNames.outputs.resourceGroupGlobalFeed
    resourceGroupHosts: resourceNames.outputs.resourceGroupHosts
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    resourceGroupStorage: resourceNames.outputs.resourceGroupStorage
    securityPrincipals: securityPrincipals
    sessionHostCount: sessionHostCount
    sessionHostIndex: sessionHostIndex
    storageCount: storageCount
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
  }
}

module sessionHosts 'modules/sessionHosts/sessionHosts.bicep' = {
  name: 'SessionHosts_${timeStamp}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    activeDirectorySolution: activeDirectorySolution
    adeKEKUrl: diskEncryptionSolution == 'ADE + KEK' ? adeKeyEncryptionKey.properties.keyUri : ''
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUAI.properties.clientId
    artifactsUserAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
    availability: availability
    availabilitySetNamePrefix: resourceNames.outputs.availabilitySetNamePrefix
    availabilitySetsCount: logic.outputs.availabilitySetsCount
    availabilitySetsIndex: logic.outputs.beginAvSetRange
    availabilityZones: availabilityZones
    cseMasterScript: cseMasterScript
    cseScriptAddDynParameters: cseScriptAddDynParameters
    cseUris: logic.outputs.cseUris
    diskEncryptionOptions: logic.outputs.diskEncryptionOptions
    diskEncryptionSetResourceId: diskEncryptionSetResourceId
    adeKeyVaultResourceId: adeKeyVaultResourceId
    adeKeyVaultUrl: !empty(adeKeyVaultResourceId) ? adeKeyVault.properties.vaultUri : ''
    diskNamePrefix: resourceNames.outputs.diskNamePrefix
    diskSku: diskSku
    divisionRemainderValue: logic.outputs.divisionRemainderValue
    domainJoinUserPassword: empty(domainJoinUserPassword) ? contains(activeDirectorySolution, 'DomainServices') ? keyVault_Reference.getSecret(domainJoinUserPassword) : '' : domainJoinUserPassword
    domainJoinUserPrincipalName: empty(domainJoinUserPrincipalName) ? contains(activeDirectorySolution, 'DomainServices') ? keyVault_Reference.getSecret(domainJoinUserPrincipalName) : '' : domainJoinUserPrincipalName
    domainName: domainName
    drainMode: false
    drainModeUserAssignedIdentityClientId: ''
    fslogixConfigureSessionHosts: fslogixConfigureSessionHosts
    fslogixContainerType: fslogixContainerType
    fslogixDeployed: logic.outputs.fslogix
    fslogixDeployedStorageAccountResourceIds: []
    fslogixExistingStorageAccountResourceIds: fslogixExistingStorageAccountResourceIds
    fslogixNetAppFileShares: fslogixNetAppFileShares
    fslogixStorageSolution: logic.outputs.fslogixStorageSolution
    hostPoolName: hostPoolName
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    customImageResourceId: customImageResourceId
    location: vmVirtualNetwork.location
    managementVirtualMachineName: ''
    maxResourcesPerTemplateDeployment: logic.outputs.maxResourcesPerTemplateDeployment
    monitoring: monitoring
    networkInterfaceNamePrefix: resourceNames.outputs.networkInterfaceNamePrefix
    ouPath: ouPath
    perfDataCollectionEndpointResourceId: perfDataCollectionEndpointResourceId
    perfDataCollectionRulesResourceIds: perfDataCollectionRulesResourceIds
    perfLogAnalyticsWorkspaceResourceId: perfLogAnalyticsWorkspaceResourceId
    pooledHostPool: logic.outputs.pooledHostPool
    recoveryServices: recoveryServices
    recoveryServicesVaultName: resourceNames.outputs.recoveryServicesVaultName
    resourceGroupControlPlane: resourceGroupControlPlane
    resourceGroupHosts: resourceNames.outputs.resourceGroupHosts
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    roleDefinitions: logic.outputs.roleDefinitions
    securityDataCollectionEndpointResourceId: securityDataCollectionEndpointResourceId
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    securityLogAnalyticsWorkspaceResourceId: securityLogAnalyticsWorkspaceResourceId
    securityPrincipalObjectIds: map(securityPrincipals, item => item.objectId)
    sessionHostBatchCount: logic.outputs.sessionHostBatchCount
    sessionHostIndex: sessionHostIndex
    storageSuffix: logic.outputs.storageSuffix
    subnetResourceId: virtualMachineSubnetResourceId
    tags: tags
    timeStamp: timeStamp
    trustedLaunch: trustedLaunch
    performanceMonitoringAgent: performanceMonitoringAgent
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineAdminPassword: empty(virtualMachineAdminPassword) ? keyVault_Reference.getSecret(virtualMachineAdminPassword) : virtualMachineAdminPassword
    virtualMachineSize: virtualMachineSize
    virtualMachineAdminUserName: empty(virtualMachineAdminUserName) ? keyVault_Reference.getSecret(virtualMachineAdminUserName) : virtualMachineAdminUserName
  }
}
