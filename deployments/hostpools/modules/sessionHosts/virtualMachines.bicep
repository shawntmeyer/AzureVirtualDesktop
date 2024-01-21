param activeDirectorySolution string
param adeKeyVaultResourceId string
param adeKeyVaultUrl string
param adeKEKUrl string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param artifactsUserAssignedIdentityResourceId string
param acceleratedNetworking string
param availability string
param availabilitySetNamePrefix string
param availabilityZones array
param perfLogAnalyticsWorkspaceResourceId string
param batchCount int
param cseMasterScript string
param cseUris array
param cseScriptAddDynParameters string
param diskEncryptionOptions object
param diskEncryptionSetResourceId string
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
param fslogixExistingStorageAccounts array
param fslogixDeployedStorageAccountResourceIds array = []
param fslogixNetAppFileShares array
param hostPoolName string
param imageOffer string
param imagePublisher string
param imageSku string
param customImageResourceId string
param location string
param managementVirtualMachineName string
param monitoring bool
param networkInterfaceNamePrefix string
param ouPath string
param perfDataCollectionEndpointResourceId string
param perfDataCollectionRulesResourceIds array
param resourceGroupControlPlane string
param resourceGroupManagement string
param securityDataCollectionEndpointResourceId string
param securityDataCollectionRulesResourceId string
param securityLogAnalyticsWorkspaceResourceId string
param sessionHostCount int
param sessionHostIndex int
param fslogixStorageSolution string
param storageSuffix string
param subnetResourceId string
param tagsNetworkInterfaces object
param tagsVirtualMachines object
param timeStamp string
param trustedLaunch string
@secure()
param virtualMachineAdminPassword string
@secure()
param virtualMachineAdminUserName string
param performanceMonitoringAgent string
param virtualMachineNamePrefix string
param virtualMachineSize string

var amdVmSize = contains(amdVmSizes, virtualMachineSize)
var amdVmSizes = [
  'Standard_NV4as_v4'
  'Standard_NV8as_v4'
  'Standard_NV16as_v4'
  'Standard_NV32as_v4'
]

// Dynamic parameters for Configure-FSLogix Script
//  cloudcache determined from fslogixContainerType parameter
var fslogixCloudCacheString = contains(fslogixContainerType, 'CloudCache') ? 'CloudCache=$true' : 'CloudCache=$false'
//  convert long activeDirectorySolution parameter values to short and SMB authentication specific values for script.
var fslogixIdP = contains(activeDirectorySolution, 'Kerberos') ? 'AADKERB' : !contains(activeDirectorySolution, 'DomainServices') ? 'AAD' : 'DomainServices'
var fslogixIdpString = 'IdP=\'${fslogixIdP}\''
var fslogixStorageSolutionString = 'StorageSolution=\'${fslogixStorageSolution}\'' 
var fslogixNetAppSharesString = fslogixStorageSolution == 'AzureNetAppFiles' && fslogixNetAppFileShares != ['None'] ? 'NetAppFileShares=\'${replace(join(fslogixNetAppFileShares, ','), ',', '\',\'')}\'' : ''
var fslogixSASuffixString = fslogixStorageSolution == 'AzureFiles' ? 'SASuffix=\'${storageSuffix}\'' : ''

// filter storage account resource ids for AAD because no sharding possible inside the region.
var fslogixNewSAResIds = !empty(fslogixDeployedStorageAccountResourceIds) ? ( fslogixIdP == 'AAD' ? fslogixDeployedStorageAccountResourceIds[0] : fslogixDeployedStorageAccountResourceIds ) : []
// get all existing storage account resource Ids from the fslogixExistingStorageAccounts object.
var fslogixExSAResIds = [for sa in fslogixExistingStorageAccounts: sa.id]
// filter fslogixExistingStorageAccounts object to only those that are not in the vm region.
var fslogixExSAResIdsInOtherRegions = [for (sa, i) in fslogixExistingStorageAccounts: sa.location != location ? sa.id : '']
// determine existing SA Resource Ids based on IdP and whether or not we deployed storage accounts. Limiting to four max storage accounts that require storage account key to allow key retrieval without loop
var fslogixExistingSAResIds = fslogixIdP == 'AAD' ? ( !empty(fslogixDeployedStorageAccountResourceIds) ? take(intersection(fslogixExSAResIds, fslogixExSAResIdsInOtherRegions), 4) : take(fslogixExSAResIds, 4) ) : fslogixExSAResIds
var fslogixSAResIds = union(fslogixNewSAResIds, fslogixExistingSAResIds)
// build storage names string
var fslogixAllSANames = [for id in fslogixSAResIds: last(split(id, '/'))]
var fslogixSANamesString = fslogixStorageSolution == 'AzureFiles' ? 'SANames=\'${replace(join(fslogixAllSANames, ','), ',', '\',\'')}\'' : ''
// build storage account keys string
var fslogixSAKey1 = fslogixIdP == 'AAD' && fslogixConfigureSessionHosts && !empty(fslogixSAResIds) ? [ storageAccounts[0].listkeys().keys[0].value ] : []
var fslogixSAKey2 = fslogixIdP == 'AAD' && fslogixConfigureSessionHosts && length(fslogixSAResIds) > 1 ? [ storageAccounts[1].listkeys().keys[0].value ] : []
var fslogixSAKey3 = fslogixIdP == 'AAD' && fslogixConfigureSessionHosts && length(fslogixSAResIds) > 2 ? [ storageAccounts[2].listkeys().keys[0].value ] : []
var fslogixSAKey4 = fslogixIdP == 'AAD' && fslogixConfigureSessionHosts && length(fslogixSAResIds) > 3 ? [ storageAccounts[3].listkeys().keys[0].value ] : []  
var fslogixSAKeysString = fslogixIdP == 'AAD' ? 'SAKeys=\'${replace(join(union(fslogixSAKey1, fslogixSAKey2, fslogixSAKey3, fslogixSAKey4), ','), ',', '\',\'')}\'' : ''
// build shares string
var fslogixSharesString = fslogixStorageSolution != 'AzureNetAppFiles' ? contains(fslogixContainerType, 'Office') ? 'ShareNames=\'profile-containers\',\'office-containers\'' : 'ShareNames=\'profile-containers\'' : ''
// build fslogix common string
var fslogixCommon = '${fslogixIdpString};${fslogixStorageSolutionString};${fslogixCloudCacheString}'
// add optional values to string
var fslogixString = fslogixStorageSolution == 'AzureNetAppFiles' ? '${fslogixCommon};${fslogixNetAppSharesString}' : fslogixIdP == 'AAD' ? '${fslogixCommon};${fslogixSASuffixString};${fslogixSANamesString};${fslogixSAKeysString};${fslogixSharesString}' : '${fslogixCommon};${fslogixSASuffixString};${fslogixSANamesString};${fslogixSharesString}'
// create custom object
var fslogixCustomObject = 'FSLogix=@([pscustomobject]@{${fslogixString}})'

// Dynamic parameters for the Anti-Malware Extension
var fslogixExclusionsCloudCache = contains(fslogixContainerType, 'CloudCache') ? ';"%ProgramData%\\FSLogix\\Cache\\*";"%ProgramData%\\FSLogix\\Proxy\\*"' : ''

var fslogixSANameMinus2 = [for name in fslogixAllSANames: take(name, length(name)-2)]
var fslogixDedupedSANames = union(fslogixSANameMinus2, fslogixSANameMinus2)
var fslogixMatchPrefix = length(fslogixDedupedSANames) == 1 ? true : false

var fslogixOfficeSharesPrefixMatch = ['\\\\${fslogixDedupedSANames[0]}??.file.${storageSuffix}\\office-containers\\*\\*.VHDX']
var fslogixProfileSharesPrefixMatch = ['\\\\${fslogixDedupedSANames[0]}??.file.${storageSuffix}\\profile-containers\\*\\*.VHDX']

var fslogixOfficeSharesNoMatch = [for name in fslogixAllSANames: '\\\\${name}.file.${storageSuffix}}\\office-containers\\*\\*.VHDX']
var fslogixProfileSharesNoMatch = [for name in fslogixAllSANames: '\\\\${name}.file.${storageSuffix}}\\profile-containers\\*\\*.VHDX']

var fslogixOfficeVHDXs = fslogixMatchPrefix ? fslogixOfficeSharesPrefixMatch : fslogixOfficeSharesNoMatch
var fslogixProfileVHDXs = fslogixMatchPrefix ? fslogixProfileSharesPrefixMatch : fslogixProfileSharesNoMatch

var fslogixExclusionsOfficeContainers = [for Path in fslogixOfficeVHDXs: '"${Path}";"${Path}.lock";"${Path}.meta";"${Path}.metadata"']
var fslogixExclusionProfileContainers = [for Path in fslogixProfileVHDXs: '"${Path}";"${Path}.lock";"${Path}.meta";"${Path}.metadata"']

var fslogixExclusionsOffice = contains(fslogixContainerType, 'Office') ? ';${join(fslogixExclusionsOfficeContainers, ';')}' : ''
var fslogixExclusionsProfile = ';${join(fslogixExclusionProfileContainers, ';')}'

var fslogixExclusions = '"%TEMP%\\*\\*.VHDX";"%Windir%\\TEMP\\*\\*.VHDX"${fslogixExclusionsCloudCache}${fslogixExclusionsProfile}${fslogixExclusionsOffice}'

// Dynamic parameters for Set-SessionHostConfiguration.ps1
//var hostPoolToken = hostPool.properties.registrationInfo.token
var hostPoolToken = reference(resourceId(resourceGroupControlPlane, 'Microsoft.DesktopVirtualization/hostPools', hostPoolName), '2019-12-10-preview').registrationInfo.token
var shcCommon = 'AmdVmSize=\'${amdVmSize}\';nvidiaVmSize=\'${nvidiaVmSize}\';HostPoolRegistrationToken=\'${hostPoolToken}\''
var shcCommonString = !empty(securityLogAnalyticsWorkspaceResourceId) && performanceMonitoringAgent == 'LogAnalyticsAgent' ? '${shcCommon};SecurityWorkspaceId=\'${securityWorkspace.properties.customerId}\';SecurityWorkspaceKey=\'${securityWorkspace.listkeys().primarySharedKey}\'' : shcCommon
var shcCommonCustomObject = 'SHConfiguration=@([pscustomobject]@{${shcCommonString}})'

// CSE Master Script Dynamic parameters - Built from any custom parameters provided via parameter and the FSLogix and SessionHostConfiguration parameters.
var cseScriptCalculatedParameters = fslogixConfigureSessionHosts ? '${fslogixCustomObject};${shcCommonCustomObject}' : '${shcCommonCustomObject}'
var cseScriptDynamicParameters = empty(cseScriptAddDynParameters) ? '@{${cseScriptCalculatedParameters}}': '@{${cseScriptCalculatedParameters};${cseScriptAddDynParameters}}'
// When sending a hashtable via powershell.exe you must use -command instead of -File in order for the parameter to be interpreted as a hashtable and not a string
var cseCommandToExecute = 'powershell -ExecutionPolicy Unrestricted -Command .\\${cseMasterScript} -DynParameters ${cseScriptDynamicParameters}'

var azureDiskEncryption = bool(diskEncryptionOptions.azureDiskEncryption)
var diskEncryptionSet = bool(diskEncryptionOptions.diskEncryptionSet)
var encryptionAtHost = bool(diskEncryptionOptions.encryptionAtHost)
var keyEncryptionKey = bool(diskEncryptionOptions.keyEncryptionKey)

var identityType = (!contains(activeDirectorySolution, 'DomainServices') || performanceMonitoringAgent == 'AzureMonitorAgent' ? true : false) ? (!empty(artifactsUserAssignedIdentityResourceId) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(artifactsUserAssignedIdentityResourceId) ? 'UserAssigned' : 'None')

var userAssignedIdentities = !empty(artifactsUserAssignedIdentityResourceId) ? {
  '${artifactsUserAssignedIdentityResourceId}': {}
} : {}

var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
} : null

var ImageReference = empty(customImageResourceId) ? {
  publisher: imagePublisher
  offer: imageOffer
  sku: imageSku
  version: 'latest'
} : {
  id: customImageResourceId
}
var intune = contains(activeDirectorySolution, 'IntuneEnrollment')
var nvidiaVmSize = contains(nvidiaVmSizes, virtualMachineSize)
var nvidiaVmSizes = [
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

resource storageAccounts 'Microsoft.Storage/storageAccounts@2023-01-01' existing = [for ResId in fslogixSAResIds: if(fslogixIdP == 'AAD' && fslogixConfigureSessionHosts && !empty(fslogixSAResIds)) {
  name: last(split(ResId, '/'))
  scope: resourceGroup(split(ResId, '/')[2], split(ResId, '/')[4])
}]

resource perfLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = if (!empty(perfLogAnalyticsWorkspaceResourceId)) {
  name: last(split(perfLogAnalyticsWorkspaceResourceId, '/'))
  scope: resourceGroup(split(perfLogAnalyticsWorkspaceResourceId, '/')[2],split(perfLogAnalyticsWorkspaceResourceId, '/')[4])
}

resource securityWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = if (!empty(securityLogAnalyticsWorkspaceResourceId)) {
  name: last(split(securityLogAnalyticsWorkspaceResourceId, '/'))
  scope: resourceGroup(split(securityLogAnalyticsWorkspaceResourceId, '/')[2],split(securityLogAnalyticsWorkspaceResourceId, '/')[4])
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
            id: subnetResourceId
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking == 'True' ? true : false
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
  identity: identity
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
            id: diskEncryptionSetResourceId
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
        Paths: fslogixExclusions
      } : {}
    }
  }
}]

resource extension_AzureMonitorWindowsAgent 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, sessionHostCount): if (monitoring && (performanceMonitoringAgent == 'AzureMonitorAgent' || !empty(securityDataCollectionRulesResourceId) || !empty(perfDataCollectionRulesResourceIds))) {
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

resource avdInsightsDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for i in range(0, sessionHostCount): if (monitoring && !empty(perfDataCollectionRulesResourceIds)) {
  scope: virtualMachine[i]
  name: 'avdinsights-${virtualMachine[i].name}-dcra'
  properties: {
    dataCollectionRuleId: perfDataCollectionRulesResourceIds[0]
    dataCollectionEndpointId: perfDataCollectionEndpointResourceId
    description: 'AVD Insights data collection rule association'
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
  ]
}]

resource vmInsightsDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for i in range(0, sessionHostCount): if (monitoring && !empty(perfDataCollectionRulesResourceIds)) {
  scope: virtualMachine[i]
  name: 'vmInsights-${virtualMachine[i].name}-dcra'
  properties: {
    dataCollectionEndpointId: perfDataCollectionEndpointResourceId
    dataCollectionRuleId: perfDataCollectionRulesResourceIds[1]
    description: 'VM Insights data collection rule association'
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
  ]
}]

resource securityDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for i in range(0, sessionHostCount): if (monitoring && !empty(securityDataCollectionRulesResourceId)) {
  scope: virtualMachine[i]
  name: 'security-${virtualMachine[i].name}-dcra'
  properties: {
    dataCollectionEndpointId: !empty(securityDataCollectionEndpointResourceId) ? securityDataCollectionEndpointResourceId : null
    dataCollectionRuleId: securityDataCollectionRulesResourceId
    description: 'Security Events data collection rule association'
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
  ]
}]

resource extension_MicrosoftMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (monitoring && (performanceMonitoringAgent == 'LogAnalyticsAgent' || !empty(securityLogAnalyticsWorkspaceResourceId))) {
  parent: virtualMachine[i]
  name: 'MicrosoftMonitoringAgent'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: monitoring && !empty(securityLogAnalyticsWorkspaceResourceId) ? securityWorkspace.properties.customerId : perfLogAnalyticsWorkspace.properties.customerId 
    }
    protectedSettings: {
      workspaceKey: monitoring && !empty(securityLogAnalyticsWorkspaceResourceId) ? securityWorkspace.listKeys().primarySharedKey : perfLogAnalyticsWorkspace.listKeys().primarySharedKey
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
      commandToExecute: cseCommandToExecute
      managedIdentity: { clientId: artifactsUserAssignedIdentityClientId }
    } : {
      commandToExecute: cseCommandToExecute
    }
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
    extension_MicrosoftMonitoringAgent
  ]
}]

// Enables drain mode on the session hosts so users cannot login to hosts immediately after the deployment
module setDrainMode '../common/customScriptExtensions.bicep' = if (drainMode) {
  name: 'CSE_DrainMode_${batchCount}_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    fileUris: [
      '${artifactsUri}Set-AvdDrainMode.ps1'
    ]
    scriptFileName: 'Set-AvdDrainMode.ps1'
    location: location
    parameters: '-environmentShortName ${environment().name} -hostPoolName ${hostPoolName} -HostPoolResourceGroupName ${resourceGroupControlPlane} -sessionHostCount ${sessionHostCount} -sessionHostIndex ${sessionHostIndex} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -userAssignedIdentityClientId ${drainModeUserAssignedIdentityClientId} -virtualMachineNamePrefix ${virtualMachineNamePrefix}'
    tags: tagsVirtualMachines
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
  dependsOn: [
    extension_CustomScriptExtension
  ]
}

resource extension_AzureDiskEncryption 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [for i in range(0, sessionHostCount): if (azureDiskEncryption) {
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
      adeKeyVaultUrl: adeKeyVaultUrl
      adeKeyVaultResourceId: adeKeyVaultResourceId
      kekVaultResourceId: keyEncryptionKey ? adeKeyVaultResourceId : null
      keyEncryptionKeyUrl: keyEncryptionKey ? adeKEKUrl : null
      ResizeOSDisk: true
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
    settings: intune ? {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    } : null
  }
}]

resource extension_AmdGpuDriverWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (amdVmSize) {
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

resource extension_NvidiaGpuDriverWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (nvidiaVmSize) {
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
