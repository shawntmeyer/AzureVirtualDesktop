param activeDirectorySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param artifactsUserAssignedIdentityResourceId string
param AcceleratedNetworking string
param availability string
param availabilitySetNamePrefix string
param availabilityZones array
param BatchCount int
param cseMasterScript string
param cseUris array
param cseScriptAddDynParameters string
param dataCollectionRulesResourceId string
param diskEncryptionOptions object
param DiskEncryptionSetResourceId string
param diskNamePrefix string
param diskSku string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param drainMode bool
param drainModeUserAssignedIdentityClientId string
param fslogixConfigureSessionHosts bool
param fslogixContainerType string
param fslogixExistingStorageAccountResourceIds array
param hostPoolName string
param imageOffer string
param imagePublisher string
param imageSku string
param customImageResourceId string
param keyVaultResourceId string
param keyVaultUrl string
param adeKEKUrl string
param location string
param AVDInsightsLogAnalyticsWorkspaceResourceId string
param managementVMName string
param monitoring bool
param netAppFileShares array
param networkInterfaceNamePrefix string
param ouPath string
param resourceGroupControlPlane string
param resourceGroupManagement string
param resourceGroupStorage string
param securityDataCollectionRulesResourceId string
param securityLogAnalyticsWorkspaceResourceId string
param sessionHostCount int
param sessionHostIndex int
@minLength(1)
param storageAccountPrefix string
param storageCount int
param storageIndex int
param storageSolution string
param storageSuffix string
param subnet string
param tagsNetworkInterfaces object
param tagsVirtualMachines object
param timeStamp string
param trustedLaunch string
param virtualMachineMonitoringAgent string
param virtualMachineNamePrefix string
@secure()
param virtualMachineAdminPassword string
param virtualMachineSize string
@secure()
param virtualMachineAdminUserName string
param virtualNetwork string
param virtualNetworkResourceGroup string

var AmdVmSize = contains(AmdVmSizes, virtualMachineSize)
var AmdVmSizes = [
  'Standard_NV4as_v4'
  'Standard_NV8as_v4'
  'Standard_NV16as_v4'
  'Standard_NV32as_v4'
]

var FslogixExclusions = '"%TEMP%\\*\\*.VHDX";"%Windir%\\TEMP\\*\\*.VHDX"${FslogixExclusionsCloudCache}${FslogixExclusionsProfileContainers}${FslogixExclusionsOfficeContainers}'
var FslogixExclusionsCloudCache = contains(fslogixContainerType, 'CloudCache') ? ';"%ProgramData%\\FSLogix\\Cache\\*";"%ProgramData%\\FSLogix\\Proxy\\*"' : ''
var FslogixOfficeShare = '\\\\${storageAccountPrefix}??.file.${storageSuffix}\\office-containers\\*\\*.VHDX'
var FslogixProfileShare = '\\\\${storageAccountPrefix}??.file.${storageSuffix}\\profile-containers\\*\\*.VHDX'
var FslogixExclusionsOfficeContainers = contains(fslogixContainerType, 'Office') ? ';"${FslogixOfficeShare}";"${FslogixOfficeShare}.lock";"${FslogixOfficeShare}.meta";"${FslogixOfficeShare}.metadata"' : ''
var FslogixExclusionsProfileContainers = ';"${FslogixProfileShare}";"${FslogixProfileShare}.lock";"${FslogixProfileShare}.meta";"${FslogixProfileShare}.metadata"'

// Dynamic parameters for Configure-FSLogix Script
//  cloudcache determined from fslogixContainerType parameter
var FslogixCloudCacheString = contains(fslogixContainerType, 'CloudCache') ? 'cloudCache=$true' : 'cloudCache=$false'
//  convert long activeDirectorySolution parameter values to short and SMB authentication specific values for script.
var FslogixIdP = contains(activeDirectorySolution, 'Kerberos') ? 'AADKERB' : !contains(activeDirectorySolution, 'DomainServices') ? 'AAD' : 'DomainServices'
var FslogixIdpString = 'idp=\'${FslogixIdP}\''
var FslogixStorageSolutionString = 'storageSolution=\'${storageSolution}\''
var FslogixNetAppSharesString = storageSolution == 'AzureNetAppFiles' && netAppFileShares != 'None' ? 'netAppFileShares=\'${replace(join(netAppFileShares, ','), ',', '\',\'')}\'' : ''
var FslogixSASuffixString = storageSolution == 'AzureFiles' ? 'saSuffix=\'${storageSuffix}\'' : ''
//  build storage account names from Storage Account parameters.
var FslogixNewSANames = [for i in range(0, storageCount): '${storageAccountPrefix}${padLeft(i + storageIndex, 2, '0')}']
//  use only first storage account per region with AAD and Storage Key. No sharding possible.
var FslogixNewStorageNames = FslogixIdP == 'AAD' ? [FslogixNewSANames[0]] : FslogixNewSANames
var FslogixExistingSANames = [for resourceId in fslogixExistingStorageAccountResourceIds: last(split(resourceId, '/')) ]
var FslogixExistingStorageNames  = FslogixIdP == 'AAD' && !empty(fslogixExistingStorageAccountResourceIds) ? [FslogixExistingSANames[0]] : FslogixExistingSANames
var FslogixSANamesString = storageSolution == 'AzureFiles' ? 'saNames=\'${replace(join(union(FslogixNewStorageNames, FslogixExistingStorageNames), ','), ',', '\',\'')}\'' : ''
//  get only the first storage account key per region with AAD and Storage Key. No sharding possible.
var FslogixSAKey = FslogixIdP == 'AAD' ? [ storageAccounts[0].listKeys().keys[0].value ] : []
var FslogixHASAKey = FslogixIdP == 'AAD' && !empty(fslogixExistingStorageAccountResourceIds) ? [ existingStorageAccountsforHA.listKeys().keys[0].value ] : []
var FslogixSAKeysString = FslogixIdP == 'AAD' ? 'saKeys=\'${replace(join(union(FslogixSAKey, FslogixHASAKey), ','), ',', '\',\'')}\'' : ''
var FslogixSharesString = storageSolution != 'AzureNetAppFiles' ? contains(fslogixContainerType, 'Office') ? 'shareNames=\'profile-containers\',\'office-containers\'' : 'shareNames=\'profile-containers\'' : ''
var FslogixCommon = '${FslogixIdpString};${FslogixStorageSolutionString};${FslogixCloudCacheString}'
var FslogixString = storageSolution == 'AzureNetAppFiles' ? '${FslogixCommon};${FslogixNetAppSharesString}' : FslogixIdP == 'AAD' ? '${FslogixCommon};${FslogixSASuffixString};${FslogixSANamesString};${FslogixSAKeysString};${FslogixSharesString}' : '${FslogixCommon};${FslogixSASuffixString};${FslogixSANamesString};${FslogixSharesString}'
var FslogixCustomObject = 'FSLogix=@([pscustomobject]@{${FslogixString}})'

// Dynamic parameters for Set-SessionHostConfiguration.ps1
//var HostPoolToken = hostPool.properties.registrationInfo.token
var HostPoolToken = reference(resourceId(resourceGroupControlPlane, 'Microsoft.DesktopVirtualization/hostPools', hostPoolName), '2019-12-10-preview').registrationInfo.token
var SHCCommon = 'AmdVmSize=\'${AmdVmSize}\';NvidiaVmSize=\'${NvidiaVmSize}\';HostPoolRegistrationToken=\'${HostPoolToken}\''
var SHCString = !empty(securityLogAnalyticsWorkspaceResourceId) && virtualMachineMonitoringAgent == 'LogAnalyticsAgent' ? '${SHCCommon};SecurityWorkspaceId=\'${reference(securityLogAnalyticsWorkspaceResourceId).customerId}\';SecurityWorkspaceKey=\'${listKeys(securityLogAnalyticsWorkspaceResourceId, '2015-03-20').primarySharedKey}\'' : SHCCommon
var SHCCustomObject = 'SHConfiguration=@([pscustomobject]@{${SHCString}})'

// CSE Master Script Dynamic parameters - Built from any custom parameters provided via parameter and the FSLogix and SessionHostConfiguration parameters.
var CSEScriptCalculatedParameters = fslogixConfigureSessionHosts ? '${FslogixCustomObject};${SHCCustomObject}' : '${SHCCustomObject}'
var CSEScriptDynamicParameters = empty(cseScriptAddDynParameters) ? '@{${CSEScriptCalculatedParameters}}': '@{${CSEScriptCalculatedParameters};${cseScriptAddDynParameters}}'
// When sending a hashtable via powershell.exe you must use -command instead of -File in order for the parameter to be interpreted as a hashtable and not a string
var CSECommandToExecute = 'powershell -ExecutionPolicy Unrestricted -Command .\\${cseMasterScript} -DynParameters ${CSEScriptDynamicParameters}'

var AzureDiskEncryption = bool(diskEncryptionOptions.AzureDiskEncryption)
var diskEncryptionSet = bool(diskEncryptionOptions.diskEncryptionSet)
var encryptionAtHost = bool(diskEncryptionOptions.encryptionAtHost)
var keyEncryptionKey = bool(diskEncryptionOptions.keyEncryptionKey)


var IdentityType = (!contains(activeDirectorySolution, 'DomainServices') || virtualMachineMonitoringAgent == 'AzureMonitorAgent' ? true : false) ? (!empty(artifactsUserAssignedIdentityResourceId) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(artifactsUserAssignedIdentityResourceId) ? 'UserAssigned' : 'None')

var UserAssignedIdentities = !empty(artifactsUserAssignedIdentityResourceId) ? {
  '${artifactsUserAssignedIdentityResourceId}': {}
} : {}

var Identity = IdentityType != 'None' ? {
  type: IdentityType
  userAssignedIdentities: !empty(UserAssignedIdentities) ? UserAssignedIdentities : null
} : null

var ImageReference = empty(customImageResourceId) ? {
  publisher: imagePublisher
  offer: imageOffer
  sku: imageSku
  version: 'latest'
} : {
  id: customImageResourceId
}
var Intune = contains(activeDirectorySolution, 'IntuneEnrollment')
var NvidiaVmSize = contains(NvidiaVmSizes, virtualMachineSize)
var NvidiaVmSizes = [
  'Standard_NV6'
  'Standard_NV12'
  'Standard_NV24'
  'Standard_NV12s_v3'
  'Standard_NV24s_v3'
  'Standard_NV48s_v3'
  'Standard_NC4as_T4_v3'
  'Standard_NC8as_T4_v3'
  'Standard_NC16as_T4_v3'
  'Standard_NC64as_T4_v3'
  'Standard_NV6ads_A10_v5'
  'Standard_NV12ads_A10_v5'
  'Standard_NV18ads_A10_v5'
  'Standard_NV36ads_A10_v5'
  'Standard_NV36adms_A10_v5'
  'Standard_NV72ads_A10_v5'
]

// call on new storage accounts only if we need the Storage Key(s)
resource storageAccounts 'Microsoft.Storage/storageAccounts@2023-01-01' existing = [for i in range(0, storageCount): if (storageSolution == 'AzureFiles' && !contains(activeDirectorySolution, 'Kerberos') && !contains(activeDirectorySolution, 'DomainServices')) {
  name: '${storageAccountPrefix}${padLeft(i + storageIndex, 2, '0')}'
  scope: resourceGroup(resourceGroupStorage)
}]

resource existingStorageAccountsforHA 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (storageSolution == 'AzureFiles' && !contains(activeDirectorySolution, 'Kerberos') && !contains(activeDirectorySolution, 'DomainServices')){
  name: last(split(fslogixExistingStorageAccountResourceIds[0], '/'))
  scope: resourceGroup(split(fslogixExistingStorageAccountResourceIds[0], '/')[2], split(fslogixExistingStorageAccountResourceIds[0], '/')[4])
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2020-05-01' = [for i in range(0, sessionHostCount): {
  name: '${networkInterfaceNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
  location: location
  tags: tagsNetworkInterfaces
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(subscription().subscriptionId, virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork, subnet)
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: AcceleratedNetworking == 'True' ? true : false
    enableIPForwarding: false
  }
}]

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, sessionHostCount): {
  name: '${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
  location: location
  tags: tagsVirtualMachines
  zones: availability == 'availabilityZones' ? [
    availabilityZones[i % length(availabilityZones)]
  ] : null
  identity: Identity
  properties: {
    availabilitySet: availability == 'AvailabilitySets' ? {
      id: resourceId('Microsoft.Compute/availabilitySets', '${availabilitySetNamePrefix}-${(i + sessionHostIndex) / 200}')
    } : null
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      imageReference: ImageReference
      osDisk: {
        name: '${diskNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
        managedDisk: {
          diskEncryptionSet: diskEncryptionSet ? {
            id: DiskEncryptionSetResourceId
          } : null
          storageAccountType: diskSku
        }
      }
      dataDisks: []
    }
    osProfile: {
      computerName: '${virtualMachineNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}'
      adminUsername: virtualMachineAdminUserName
      adminPassword: virtualMachineAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${networkInterfaceNamePrefix}${padLeft((i + sessionHostIndex), 3, '0')}')
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: {
      uefiSettings: trustedLaunch == 'true' ? {
        secureBootEnabled: true
        vTpmEnabled: true
      } : null
      securityType: trustedLaunch == 'true' ? 'trustedLaunch' : null
      encryptionAtHost: encryptionAtHost
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    licenseType: ((imagePublisher == 'MicrosoftWindowsDesktop' || !empty(customImageResourceId)) ? 'Windows_Client' : 'Windows_Server')
  }
  dependsOn: [
    networkInterface
  ]
}]

resource extension_IaasAntimalware 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): {
  parent: virtualMachine[i]
  name: 'IaaSAntimalware'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: 'true'
      ScheduledScanSettings: {
        isEnabled: 'true'
        day: '7' // Day of the week for scheduled scan (1-Sunday, 2-Monday, ..., 7-Saturday)
        time: '120' // When to perform the scheduled scan, measured in minutes from midnight (0-1440). For example: 0 = 12AM, 60 = 1AM, 120 = 2AM.
        scanType: 'Quick' //Indicates whether scheduled scan setting type is set to Quick or Full (default is Quick)
      }
      Exclusions: fslogixConfigureSessionHosts ? {
        Paths: FslogixExclusions
      } : {}
    }
  }
}]

resource extension_AzureMonitorWindowsAgent 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, sessionHostCount): if ((monitoring && virtualMachineMonitoringAgent == 'AzureMonitorAgent') || !empty(securityDataCollectionRulesResourceId)) {
  parent: virtualMachine[i]
  name: 'AzureMonitorAgent'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
  dependsOn: [
    extension_IaasAntimalware
  ]
}]

resource avdInsightsDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for i in range(0, sessionHostCount): if (monitoring && virtualMachineMonitoringAgent == 'AzureMonitorAgent') {
  scope: virtualMachine[i]
  name: 'avdinsights-${virtualMachine[i].name}-dcra'
  properties: {
    dataCollectionRuleId: dataCollectionRulesResourceId
    description: 'AVD Insights data collection rule association'
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
  ]
}]

resource securityDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for i in range(0, sessionHostCount): if (!empty(securityDataCollectionRulesResourceId)) {
  scope: virtualMachine[i]
  name: 'security-${virtualMachine[i].name}-dcra'
  properties: {
    dataCollectionRuleId: securityDataCollectionRulesResourceId
    description: 'Security Events data collection rule association'
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
  ]
}]

resource extension_MicrosoftMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if ((monitoring && virtualMachineMonitoringAgent == 'LogAnalyticsAgent') || !empty(securityLogAnalyticsWorkspaceResourceId)) {
  parent: virtualMachine[i]
  name: 'MicrosoftMonitoringAgent'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: monitoring && virtualMachineMonitoringAgent == 'LogAnalyticsAgent' ? reference(AVDInsightsLogAnalyticsWorkspaceResourceId).customerId : (!empty(securityLogAnalyticsWorkspaceResourceId) ? reference(securityLogAnalyticsWorkspaceResourceId).customerId : null)
    }
    protectedSettings: {
      workspaceKey: monitoring && virtualMachineMonitoringAgent == 'LogAnalyticsAgent' ? listKeys(AVDInsightsLogAnalyticsWorkspaceResourceId, '2022-10-01').primarySharedKey : (!empty(securityLogAnalyticsWorkspaceResourceId) ? listKeys(securityLogAnalyticsWorkspaceResourceId, '2022-10-01').primarySharedKey : null)
    }
  }
  dependsOn: [
    extension_IaasAntimalware
  ]
}]

resource extension_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): {
  parent: virtualMachine[i]
  name: 'CustomScriptExtension'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: cseUris
      timeStamp: timeStamp
    }    
    protectedSettings: contains(artifactsUri, environment().suffixes.storage) ? {
      commandToExecute: CSECommandToExecute
      managedIdentity: { clientId: artifactsUserAssignedIdentityClientId }
    } : {
      commandToExecute: CSECommandToExecute
    }
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
    extension_MicrosoftMonitoringAgent
  ]
}]

// Enables drain mode on the session hosts so users cannot login to hosts immediately after the deployment
module setDrainMode '../management/customScriptExtensions.bicep' = if (drainMode) {
  name: 'CSE_DrainMode_${BatchCount}_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    artifactsUri: artifactsUri
    files: ['Set-AvdDrainMode.ps1']
    executeScript: 'Set-AvdDrainMode.ps1'
    location: location
    parameters: '-environmentShortName ${environment().name} -hostPoolName ${hostPoolName} -HostPoolResourceGroupName ${resourceGroupControlPlane} -sessionHostCount ${sessionHostCount} -sessionHostIndex ${sessionHostIndex} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -userAssignedIdentityClientId ${drainModeUserAssignedIdentityClientId} -virtualMachineNamePrefix ${virtualMachineNamePrefix}'
    tags: tagsVirtualMachines
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVMName
  }
  dependsOn: [
    extension_CustomScriptExtension
  ]
}

resource extension_AzureDiskEncryption 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [for i in range(0, sessionHostCount): if (AzureDiskEncryption) {
  parent: virtualMachine[i]
  name: 'AzureDiskEncryption'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'AzureDiskEncryption'
    typeHandlerVersion: '2.2'
    autoUpgradeMinorVersion: true
    settings: {
      EncryptionOperation: 'EnableEncryption'
      KeyEncryptionAlgorith: 'RSA-OAEP-256'
      KeyVaultURL: keyVaultUrl
      keyVaultResourceId: keyVaultResourceId
      keyEncryptionKeyUrl: keyEncryptionKey ? adeKEKUrl : null
      VolumeType: 'All'
    }
  }
}]

resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (contains(activeDirectorySolution, 'DomainServices')) {
  parent: virtualMachine[i]
  name: 'JsonADDomainExtension'
  location: location
  tags: tagsVirtualMachines
  properties: {
    forceUpdateTag: timeStamp
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: domainName
      User: domainJoinUserPrincipalName
      Restart: 'true'
      Options: '3'
      OUPath: ouPath
    }
    protectedSettings: {
      Password: domainJoinUserPassword
    }
  }
}]

resource extension_AADLoginForWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (!contains(activeDirectorySolution, 'DomainServices')) {
  parent: virtualMachine[i]
  name: 'AADLoginForWindows'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: Intune ? {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    } : null
  }
}]

resource extension_AmdGpuDriverWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (AmdVmSize) {
  parent: virtualMachine[i]
  name: 'AmdGpuDriverWindows'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.HpcCompute'
    type: 'AmdGpuDriverWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {}
  }
  dependsOn: [
    extension_AADLoginForWindows
    extension_JsonADDomainExtension
  ]
}]

resource extension_NvidiaGpuDriverWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (NvidiaVmSize) {
  parent: virtualMachine[i]
  name: 'NvidiaGpuDriverWindows'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.HpcCompute'
    type: 'NvidiaGpuDriverWindows'
    typeHandlerVersion: '1.2'
    autoUpgradeMinorVersion: true
    settings: {}
  }
  dependsOn: [
    extension_AADLoginForWindows
    extension_JsonADDomainExtension
  ]
}]
