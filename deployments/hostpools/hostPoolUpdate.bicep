targetScope = 'subscription'

// Resource and Resource Group naming and organization

@description('Reverse the normal Cloud Adoption Framework naming convention by putting the resource type abbreviation at the end of the resource name.')
param nameConvResTypeAtEnd bool = false

@description('The resource ID of the AVD hostpool to update.')
param hostPoolResourceId string

@description('The name of the Resource Group to where the AVD Session Hosts are to be deployed.')
param resourceGroupHosts string = ''

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

// Profile Storage Configuration

@allowed([
  'CloudCacheProfileContainer' // FSLogix Cloud Cache Profile Container
  'CloudCacheProfileOfficeContainer' // FSLogix Cloud Cache Profile & Office Container
  'ProfileContainer' // FSLogix Profile Container
  'ProfileOfficeContainer' // FSLogix Profile & Office Container
])
param fslogixContainerType string = 'ProfileContainer'

@description('Configure FSLogix agent on the session hosts via local registry keys for Entra Id identity only.')
param fslogixConfigureSessionHosts bool = true

@description('Optional. The name of the blob that contains the FSLogix Configuration Script.')
param fslogixConfigurationBlobName string = 'FSLogix-Configure.zip'

@description('''Existing FSLogix Storage Account Resource Ids. Only used when fslogixConfigureSessionHosts = "true".
This list will be added to any storage accounts created when setting "fslogixStorageService" to any of the AzureFiles options. 
If "identitySolution" is set to "EntraId" or "EntraIdIntuneEnrollment" then only the first storage account listed will be used.
''')
param fslogixExistingStorageAccountResourceIds array = []

// Control Plane Configuration

@maxValue(5000)
@minValue(0)
@description('The number of session hosts to deploy in the host pool. Ensure you have the approved quota to deploy the desired count.')
param sessionHostCount int = 1

@maxValue(4999)
@minValue(0)
@description('The starting number for the session hosts. This is important when adding virtual machines to ensure an update deployment is not performed on an exiting, active session host.')
param sessionHostIndex int = 1

// Session Host/VM Configuration
@description('Enable accelerated networking on the AVD session hosts.')
param acceleratedNetworking bool = true

@allowed([
  'availabilitySets'
  'availabilityZones'
  'None'
])
@description('Set the desired availability / SLA with a pooled host pool.  The best practice is to deploy to availability Zones for resilency.')
param availability string = 'availabilityZones'

@description('Optional. The name of the blob containing the AVDAgent Agent installers and script.')
param avdAgentInstallersBlobName string = 'Set-SessionHostConfiguration.zip'

@description('Optional. Confidential disk encryption is an additional layer of encryption which binds the disk encryption keys to the virtual machine TPM and makes the disk content accessible only to the VM.')
param confidentialVMOSDiskEncryption bool = false

@description('''Optional. Encryption at host encrypts temporary disks and ephemeral OS disks with platform-managed keys,
OS and data disk caches with the key specified in the "keyManagementDisksAndStorage" parameter, and flows encrypted to the Storage service.
''')
param encryptionAtHost bool = true

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

@description('Optional. The resource ID of the Azure Disk Encryption Set to use to protect the ADE encryption keys. Only valid when diskEncryptionSolution specifies customer managed keys.')
param diskEncryptionSetResourceId string = ''

@allowed([
  'Standard'
  'ConfidentialVM'
  'TrustedLaunch'
])
@description('Optional. The Security Type of the AVD Session Hosts.  ConfidentialVM and TrustedLaunch are only available in certain regions.')
param virtualMachineSecurityType string = 'TrustedLaunch'

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

@minLength(2)
@maxLength(12)
@description('Required. The Virtual Machine Name prefix.')
param virtualMachineNamePrefix string

// Monitoring Configuration
@description('Deploys the required enableInsights resources to enable AVD Insights and monitor features in the automation account.')
param enableInsights bool = true

@description('Optional. The resource ID of the Data Collection Endpoint located in the same region as the Virtual Machines.')
param dataCollectionEndpointResourceId string = ''

@description('Optional. The resource ID of the Data Collection Rules used with the Azure Monitor Agent to power AVD insights.')
param avdInsightsDataCollectionRulesResourceId string = ''

@description('Optional. The resource ID of the Data Collection Rules used with the Azure Monitor Agent to power VM insights.')
param vmInsightsDataCollectionRulesResourceId string = ''

@description('The resource ID of the log analytics workspace used for Azure Sentinel and / or Defender for Cloud. When using the Microsoft Monitor Agent (Log Analytics Agent), this allows you to multihome the agent to reduce unnecessary log collection and reduce cost.')
param securityLogAnalyticsWorkspaceResourceId string = ''

@description('The resource ID of the data collection rule used for Azure Sentinel and / or Defender for Cloud when using the Azure Monitor Agent.')
param securityDataCollectionRulesResourceId string = ''

// Backup Configuration

@description('Enable backups to an Azure Recovery Services vault.  For a pooled host pool this will enable backups on the Azure file share.  For a personal host pool this will enable backups on the AVD sessions hosts.')
param recoveryServices bool = false

@description('The resource ID of the Recovery Services Vault to use for backups.')
param recoveryServicesVaultResourceId string = ''

// Tags
@description('Key / value pairs of metadata for the Azure resource groups and resources.')
param tags object = {}

@description('DO NOT MODIFY THIS VALUE! The timeStamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param timeStamp string = utcNow('yyyyMMddhhmmss')

var acceleratedNetworkingString = acceleratedNetworking ? 'True' : 'False'
var confidentialVMOSDiskEncryptionType = confidentialVMOSDiskEncryption ? 'DiskWithVMGuestState' : 'VMGuestStateOnly'

var securityType = virtualMachineSecurityType == 'Standard' ? '' : virtualMachineSecurityType

var resourceAbbreviations = loadJsonContent('../../.common/data/resourceAbbreviations.json')

var availabilitySetNamePrefix = nameConvResTypeAtEnd ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.availabilitySets}-' : '${resourceAbbreviations.availabilitySets}-${vmNamePrefixWithoutDash}-'
var vmNamePrefixWithoutDash = last(virtualMachineNamePrefix) == '-' ? take(virtualMachineNamePrefix, length(virtualMachineNamePrefix) - 1) : virtualMachineNamePrefix
var diskNamePrefix = nameConvResTypeAtEnd ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.disks}-' : '${resourceAbbreviations.disks}-${vmNamePrefixWithoutDash}-'
var networkInterfaceNamePrefix = nameConvResTypeAtEnd ? '${vmNamePrefixWithoutDash}-${resourceAbbreviations.networkInterfaces}-' : '${resourceAbbreviations.networkInterfaces}-${vmNamePrefixWithoutDash}-'

var artifactsStorageAccountName = last(split(artifactsStorageAccountResourceId, '/'))
var artifactsUri = 'https://${artifactsStorageAccountName}.blob.${environment().suffixes.storage}/${artifactsContainerName}/'
var availabilityZones = availability == 'availabilityZones' ? [
  '1'
  '2'
  '3'
] : []
var locationVirtualMachines = vmVirtualNetwork.location
var recoveryServicesVaultName = !empty(recoveryServicesVaultResourceId) ? last(split(recoveryServicesVaultResourceId, '/')) : ''
var resourceGroupControlPlane = split(hostPoolResourceId, '/')[4]
var resourceGroupManagement = !empty(recoveryServicesVaultResourceId) ? split(recoveryServicesVaultResourceId, '/')[4] : ''

var hostPoolName = last(split(hostPoolResourceId, '/'))

resource artifactsUAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: last(split(artifactsUserAssignedIdentityResourceId, '/'))
  scope: resourceGroup(split(artifactsUserAssignedIdentityResourceId, '/')[2], split(artifactsUserAssignedIdentityResourceId, '/')[4])
}

resource vmVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: split(virtualMachineSubnetResourceId, '/')[8]
  scope: resourceGroup(split(virtualMachineSubnetResourceId, '/')[2], split(virtualMachineSubnetResourceId, '/')[4])
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' existing = {
  name: last(split(hostPoolResourceId, '/'))
  scope: resourceGroup(split(hostPoolResourceId, '/')[2], split(hostPoolResourceId, '/')[4])
}

// Resource Names
module resourceNames 'modules/resourceNames.bicep' = {
  name: 'ResourceNames_${timeStamp}'
  params: {
    environmentShortName: environmentShortName
    businessUnitIdentifier: ''
    centralizedAVDMonitoring: false
    fslogixStorageCustomPrefix: 'notused'
    hostPoolIdentifier: 'notused'
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
    identitySolution: identitySolution
    artifactsUri: artifactsUri
    avdAgentInstallersBlobName: avdAgentInstallersBlobName
    avdPrivateLink: false
    cseMasterScript: cseMasterScript
    diskSku: diskSku
    cseBlobNames: cseBlobNames
    domainName: domainName
    fileShareNames: resourceNames.outputs.fileShareNames
    fslogixConfigureSessionHosts: fslogixConfigureSessionHosts
    fslogixConfigurationBlobName: fslogixConfigurationBlobName
    fslogixContainerType: fslogixContainerType
    fslogixStorageService: 'None'
    hostPoolType: 'Pooled DepthFirst'
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    locations: resourceNames.outputs.locations
    locationVirtualMachines: locationVirtualMachines
    resourceGroupControlPlane: resourceGroupControlPlane
    resourceGroupGlobalFeed: resourceNames.outputs.resourceGroupGlobalFeed
    resourceGroupHosts: resourceGroupHosts
    resourceGroupManagement: resourceGroupManagement
    resourceGroupStorage: resourceNames.outputs.resourceGroupStorage
    securityPrincipals: []
    sessionHostCount: sessionHostCount
    sessionHostIndex: sessionHostIndex
    fslogixStorageCount: 1
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineSize: virtualMachineSize
    resourceGroupMonitoring: resourceNames.outputs.resourceGroupMonitoring
  }
}

module sessionHosts 'modules/sessionHosts/sessionHosts.bicep' = {
  name: 'SessionHosts_${timeStamp}'
  params: {
    acceleratedNetworking: acceleratedNetworkingString
    identitySolution: identitySolution
    artifactsUri: artifactsUri
    artifactsUserAssignedIdentityClientId: artifactsUAI.properties.clientId
    artifactsUserAssignedIdentityResourceId: artifactsUserAssignedIdentityResourceId
    availability: availability
    availabilitySetNamePrefix: availabilitySetNamePrefix
    availabilitySetsCount: logic.outputs.availabilitySetsCount
    availabilitySetsIndex: logic.outputs.beginAvSetRange
    availabilityZones: availabilityZones
    avdInsightsDataCollectionRulesResourceId: avdInsightsDataCollectionRulesResourceId
    confidentialVMOSDiskEncryptionType: confidentialVMOSDiskEncryptionType
    cseMasterScript: cseMasterScript
    cseScriptAddDynParameters: cseScriptAddDynParameters
    cseUris: logic.outputs.cseUris
    dataCollectionEndpointResourceId: dataCollectionEndpointResourceId
    diskEncryptionSetResourceId: diskEncryptionSetResourceId
    diskNamePrefix: diskNamePrefix
    diskSku: diskSku
    divisionRemainderValue: logic.outputs.divisionRemainderValue
    domainJoinUserPassword: domainJoinUserPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainName: domainName
    drainMode: false
    drainModeUserAssignedIdentityClientId: ''
    encryptionAtHost: encryptionAtHost
    fslogixConfigureSessionHosts: logic.outputs.fslogixConfigureSessionHosts
    fslogixContainerType: fslogixContainerType
    fslogixDeployedStorageAccountResourceIds: []
    fslogixExistingStorageAccountResourceIds: fslogixExistingStorageAccountResourceIds
    hostPoolName: hostPoolName
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSku: imageSku
    customImageResourceId: customImageResourceId
    location: vmVirtualNetwork.location
    managementVirtualMachineName: ''
    maxResourcesPerTemplateDeployment: logic.outputs.maxResourcesPerTemplateDeployment
    enableInsights: enableInsights
    networkInterfaceNamePrefix: networkInterfaceNamePrefix
    ouPath: ouPath
    pooledHostPool: hostPool.properties.hostPoolType == 'Pooled' ? true : false
    recoveryServices: recoveryServices
    recoveryServicesVaultName: recoveryServicesVaultName
    resourceGroupControlPlane: resourceGroupControlPlane
    resourceGroupHosts: resourceGroupHosts
    resourceGroupManagement: resourceGroupManagement
    roleDefinitions: logic.outputs.roleDefinitions
    securityDataCollectionRulesResourceId: securityDataCollectionRulesResourceId
    securityLogAnalyticsWorkspaceResourceId: securityLogAnalyticsWorkspaceResourceId
    securityPrincipalObjectIds: []
    sessionHostBatchCount: logic.outputs.sessionHostBatchCount
    sessionHostIndex: sessionHostIndex
    storageSuffix: logic.outputs.storageSuffix
    subnetResourceId: virtualMachineSubnetResourceId
    tags: tags
    timeStamp: timeStamp
    securityType: securityType
    virtualMachineNamePrefix: virtualMachineNamePrefix
    virtualMachineAdminPassword: virtualMachineAdminPassword
    virtualMachineSize: virtualMachineSize
    virtualMachineAdminUserName: virtualMachineAdminUserName
    vmInsightsDataCollectionRulesResourceId: vmInsightsDataCollectionRulesResourceId
  }
}
