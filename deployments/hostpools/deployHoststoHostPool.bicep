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

@description('''Conditional. When the "businessUnitIdentifier" parameter is not empty, this parameter determines if the AVD Management Resource Group and associated resources
are created in a centralized resource group (does not include "businessUnitIdentifier" in the name) and management resources are named accordingly or if a Business unit
specific AVD management resource group is created and management resources are named accordingly.
If the "businessUnitIdentifier" parameter is left empty ("") then this value has no effect.
''')
param centralizedAVDManagement bool = false

@maxLength(10)
@description('An identifier used to distinquish each host pool. This can represent the user or use case.')
param hostPoolIdentifier string

@description('The resource ID of the resource group to update.  If not specified, a new resource group will be created.')
param existingComputeResourceGroupName string = ''

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

@description('The custom prefix to use for the name of the Azure files storage accounts to use for FSLogix. If not specified, the name is generated automatically.')
param fslogixStorageCustomPrefix string = ''

@allowed([
  'CloudCacheProfileContainer' // FSLogix Cloud Cache Profile Container
  'CloudCacheProfileOfficeContainer' // FSLogix Cloud Cache Profile & Office Container
  'ProfileContainer' // FSLogix Profile Container
  'ProfileOfficeContainer' // FSLogix Profile & Office Container
])
param fslogixContainerType string = 'ProfileContainer'

@description('Configure FSLogix agent on the session hosts via local registry keys.')
param fslogixConfigureSessionHosts bool = true

@description('Optional. The name of the blob that contains the FSLogix Configuration Script.')
param fslogixConfigurationBlobName string = 'FSLogix-Configure.zip'

@description('''Existing FSLogix Storage Account Resource Ids. Only used when fslogixConfigureSessionHosts = "true".
This list will be added to any storage accounts created when setting "fslogixStorageService" to any of the AzureFiles options. 
If "activeDirectorySolution" is set to "AzureActiveDirectory" or "AzureActiveDirectoryIntuneEnrollment" then only the first storage account listed will be used.
''')
param fslogixExistingStorageAccountResourceIds array = []

@description('FSLogix Storage Account Resource Ids. Only used when fslogixConfigureSessionHosts = true.')
param fslogixStorageAccountResourceIds array = []

// Control Plane Configuration

@description('The resource ID of the AVD Hostpool to update.')
param hostPoolResourceId string

@description('The deployment location for the AVD management resources.')
param locationControlPlane string = deployment().location

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

@description('Optional. The availability zones to deploy the AVD session hosts.  If not specified, the session hosts will be deployed to the default zone.')
@allowed([
  1
  2
  3
])
param availabilityZones array = [
  1
  2
  3
]

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
  'ADE'       // Azure Disk Encryption
  'ADE + KEK' // Azure Disk Encryption with Key Encryption Key
])
@description('Optional. The VM disk encryption configuration. (Default: "SSE + PMK")')
param diskEncryptionSolution string = 'SSE + PMK'

@description('Optional. The resource ID of the disk encryption set to use for the AVD session host disks to be used for Customer Managed Keys.')
param diskEncryptionSetResourceId string = ''

@description('Optional. The resource ID of the key vault to use for encrypting AVD session host disks to with Azure Disk Encryption.')
param azureDiskEncryptionKeyVaultResourceId string = ''

@description('Optional. The resource ID of the key encryption key to use for encrypting AVD session host disks with Azure Disk Encryption.')
param azureDiskEncryptionKeyEncryptionKeyResourceId string = ''

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

@description('The resource ID of the log analytics workspace used for Azure Virtual Desktop Insights.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Optional. The resource ID of the data collection rule used for Azure Virtual Desktop Insights.')
param dataCollectionRulesResourceId string = ''

@description('The resource ID of the log analytics workspace used for Azure Sentinel and / or Defender for Cloud. When using the Microsoft monitoring Agent, this allows you to multihome the agent to reduce unnecessary log collection and reduce cost.')
param securityLogAnalyticsWorkspaceResourceId string = ''

@description('An array of data collection rule resource Ids used for Azure Sentinel and / or Defender for Cloud when using the Azure Monitor Agent.')
param securityDataCollectionRulesResourceId string = ''

@allowed([
  'AzureMonitorAgent'
  'LogAnalyticsAgent'
])
@description('Input the desired monitoring agent to send events and performance counters to a log analytics workspace.')
param virtualMachineMonitoringAgent string = 'AzureMonitorAgent'

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

// Existing Virtual Network location
resource vmVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: split(virtualMachineSubnetResourceId, '/')[8]
  scope: resourceGroup(split(virtualMachineSubnetResourceId, '/')[2], split(virtualMachineSubnetResourceId, '/')[4])
}

resource adeKeyEncryptionKey 'Microsoft.KeyVault/vaults/keys@2022-07-01' existing = if(!empty(azureDiskEncryptionKeyEncryptionKeyResourceId) && diskEncryptionSolution == 'ADE + KEK') {
  name: last(split(azureDiskEncryptionKeyEncryptionKeyResourceId, '/'))
  scope: resourceGroup(split(azureDiskEncryptionKeyEncryptionKeyResourceId, '/')[2], split(azureDiskEncryptionKeyEncryptionKeyResourceId, '/')[4])
}

resource adeKeyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = if(!empty(azureDiskEncryptionKeyVaultResourceId) && contains(diskEncryptionSolution, 'ADE'))  {
  name: last(split(azureDiskEncryptionKeyVaultResourceId, '/'))
  scope: resourceGroup(split(azureDiskEncryptionKeyVaultResourceId, '/')[2], split(azureDiskEncryptionKeyVaultResourceId, '/')[4])
}

resource artifactsUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: last(split(artifactsUserAssignedIdentityResourceId, '/'))
  scope: resourceGroup(split(artifactsUserAssignedIdentityResourceId, '/')[2], split(artifactsUserAssignedIdentityResourceId, '/')[4])
}

// Resource Names
module resourceNames 'modules/resourceNames.bicep' = {
  name: 'ResourceNames_${timeStamp}'
  params: {
    environmentShortName: environmentShortName
    businessUnitIdentifier: businessUnitIdentifier
    centralizedAVDManagement: centralizedAVDManagement
    fslogixStorageCustomPrefix: fslogixStorageCustomPrefix
    hostPoolIdentifier: hostPoolIdentifier
    locationControlPlane: locationControlPlane
    locationVirtualMachines: vmVirtualNetwork.location
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
    fslogixStorageService: 'None'
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    locations: resourceNames.outputs.locations
    locationVirtualMachines: vmVirtualNetwork.location
    resourceGroupControlPlane: resourceNames.outputs.resourceGroupControlPlane
    resourceGroupGlobalFeed: resourceNames.outputs.resourceGroupGlobalFeed
    resourceGroupHosts: resourceNames.outputs.resourceGroupHosts
    resourceGroupManagement: resourceNames.outputs.resourceGroupManagement
    resourceGroupStorage: resourceNames.outputs.resourceGroupStorage
    securityPrincipals: securityPrincipals
    sessionHostCount: sessionHostCount
    sessionHostIndex: sessionHostIndex
    storageCount: 0
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
  }
}

// Resource Groups
module resGroup 'modules/resourceGroups.bicep' =  if(empty(existingComputeResourceGroupName)) {
  name: 'ResourceGroup_Hosts_${timeStamp}'
  params: {
    location: locationVirtualMachines
    resourceGroupName: resourceNames.outputs.resourceGroupHosts
    tags: tags
  }
}

module sessionHosts 'modules/sessionHosts/sessionHosts.bicep' = {
  name: 'SessionHosts_${timeStamp}'
  params: {
    acceleratedNetworking: 'True'
    activeDirectorySolution: activeDirectorySolution
    adeKEKUrl: diskEncryptionSolution == 'ADE' ? adeKeyEncryptionKey.properties.keyUri : ''
    adeKeyVaultResourceId: contains(diskEncryptionSolution, 'ADE') ? azureDiskEncryptionKeyVaultResourceId : ''
    adeKeyVaultUrl: contains(diskEncryptionSolution, 'ADE') ? adeKeyVault.properties.vaultUri : ''
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUserAssignedIdentity.properties.clientId
    artifactsUserAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
    automationAccountName: resourceNames.outputs.automationAccountName
    availability: availability
    availabilitySetNamePrefix: resourceNames.outputs.availabilitySetNamePrefix
    availabilitySetsCount: logic.outputs.availabilitySetsCount
    availabilitySetsIndex: logic.outputs.beginAvSetRange
    availabilityZones: availabilityZones
    avdInsightsLogAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    cseMasterScript: cseMasterScript
    cseScriptAddDynParameters: cseScriptAddDynParameters
    cseUris: logic.outputs.cseUris
    dataCollectionRulesResourceId: !empty(dataCollectionRulesResourceId) ? dataCollectionRulesResourceId : ''
    diskEncryptionOptions: logic.outputs.diskEncryptionOptions
    diskEncryptionSetResourceId: contains(diskEncryptionSolution, 'CMK') ? diskEncryptionSetResourceId : ''
    diskNamePrefix: resourceNames.outputs.diskNamePrefix
    diskSku: diskSku
    divisionRemainderValue: logic.outputs.divisionRemainderValue
    domainJoinUserPassword: contains(activeDirectorySolution, 'DomainServices') ? domainJoinUserPassword : ''
    domainJoinUserPrincipalName: contains(activeDirectorySolution, 'DomainServices') ? domainJoinUserPrincipalName : ''
    domainName: domainName
    drainMode: false
    drainModeUserAssignedIdentityClientId: ''
    fslogixContainerType: fslogixContainerType
    fslogixExistingStorageAccountResourceIds: fslogixExistingStorageAccountResourceIds
    fslogixConfigureSessionHosts: fslogixConfigureSessionHosts
    fslogixStorageAccountResourceIds: fslogixStorageAccountResourceIds
    fslogixDeployed: false
    hostPoolName: last(split(hostPoolResourceId, '/'))
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    customImageResourceId: customImageResourceId
    location: vmVirtualNetwork.location
    managementVMName: ''
    maxResourcesPerTemplateDeployment: logic.outputs.maxResourcesPerTemplateDeployment
    monitoring: monitoring
    netAppFileShares: ['None']
    networkInterfaceNamePrefix: resourceNames.outputs.networkInterfaceNamePrefix
    ouPath: ouPath
    pooledHostPool: logic.outputs.pooledHostPool
    recoveryServices: recoveryServices
    recoveryServicesVaultName: resourceNames.outputs.recoveryServicesVaultName
    resourceGroupControlPlane: split(hostPoolResourceId, '/')[4]
    resourceGroupHosts: empty(existingComputeResourceGroupName) ? resourceNames.outputs.resourceGroupHosts : existingComputeResourceGroupName
    resourceGroupManagement: ''
    roleDefinitions: logic.outputs.roleDefinitions
    runBookUpdateUserAssignedIdentityClientId: ''
    scalingBeginPeakTime: ''
    scalingEndPeakTime: ''
    scalingLimitSecondsToForceLogOffUser: ''
    scalingMinimumNumberOfRdsh: ''
    scalingSessionThresholdPerCPU: ''
    scalingTool: false
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    securityPrincipalObjectIds: map(securityPrincipals, item => item.objectId)
    securityLogAnalyticsWorkspaceResourceId: securityLogAnalyticsWorkspaceResourceId
    sessionHostBatchCount: logic.outputs.sessionHostBatchCount
    sessionHostIndex: sessionHostIndex
    fslogixStorageAccountPrefix: resourceNames.outputs.storageAccountNamePrefix
    fslogixStorageSolution: logic.outputs.fslogixStorageSolution
    storageSuffix: logic.outputs.storageSuffix
    subnetResourceId: virtualMachineSubnetResourceId
    tags: tags
    timeDifference: logic.outputs.timeDifference
    timeStamp: timeStamp
    timeZone: logic.outputs.timeZone
    trustedLaunch: 'true'
    virtualMachineMonitoringAgent: virtualMachineMonitoringAgent
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineAdminUserName: virtualMachineAdminUserName
    virtualMachineSize: virtualMachineSize
  }
  dependsOn: [
    resGroup
  ]
}
