param identitySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param artifactsUserAssignedIdentityResourceId string
param acceleratedNetworking string
param availability string
param availabilitySetNamePrefix string
param availabilityZones array
param batchCount int
param confidentialVMOSDiskEncryptionType string
param cseMasterScript string
param cseUris array
param cseScriptAddDynParameters string
param dataCollectionEndpointResourceId string
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
param encryptionAtHost bool
param fslogixConfigureSessionHosts bool
param fslogixContainerType string
param fslogixStorageAccountResourceIds array
param hostPoolName string
param imageOffer string
param imagePublisher string
param imageSku string
param customImageResourceId string
param location string
param managementVirtualMachineName string
param enableMonitoring bool
param networkInterfaceNamePrefix string
param ouPath string
param avdInsightsDataCollectionRulesResourceId string
param vmInsightsDataCollectionRulesResourceId string
param resourceGroupControlPlane string
param resourceGroupManagement string
param securityDataCollectionRulesResourceId string
param securityLogAnalyticsWorkspaceResourceId string
param securityType string
param sessionHostCount int
param sessionHostIndex int
param storageSuffix string
param subnetResourceId string
param tagsNetworkInterfaces object
param tagsVirtualMachines object
param timeStamp string
@secure()
param virtualMachineAdminPassword string
@secure()
param virtualMachineAdminUserName string
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

var fslogixSASuffixString = 'SASuffix=\'${storageSuffix}\''
// build storage names string
var fslogixStorageAccountNames = [for id in fslogixStorageAccountResourceIds: last(split(id, '/'))]
var fslogixSANamesString = 'SANames=\'${replace(join(fslogixStorageAccountNames, ','), ',', '\',\'')}\''
// build storage account keys string
var fslogixSAKey1 = fslogixConfigureSessionHosts && !empty(fslogixStorageAccountResourceIds) ? [ storageAccounts[0].listkeys().keys[0].value ] : []
var fslogixSAKey2 = fslogixConfigureSessionHosts && length(fslogixStorageAccountResourceIds) > 1 ? [ storageAccounts[1].listkeys().keys[0].value ] : []
var fslogixSAKey3 = fslogixConfigureSessionHosts && length(fslogixStorageAccountResourceIds) > 2 ? [ storageAccounts[2].listkeys().keys[0].value ] : []
var fslogixSAKey4 = fslogixConfigureSessionHosts && length(fslogixStorageAccountResourceIds) > 3 ? [ storageAccounts[3].listkeys().keys[0].value ] : []  
var fslogixSAKeysString = 'SAKeys=\'${replace(join(union(fslogixSAKey1, fslogixSAKey2, fslogixSAKey3, fslogixSAKey4), ','), ',', '\',\'')}\''
// build shares string
var fslogixSharesString = contains(fslogixContainerType, 'Office') ? 'ShareNames=\'profile-containers\',\'office-containers\'' : 'ShareNames=\'profile-containers\''
// build fslogix common string
var fslogixCommon = fslogixCloudCacheString
// add optional values to string
var fslogixString = '${fslogixCommon};${fslogixSASuffixString};${fslogixSANamesString};${fslogixSAKeysString};${fslogixSharesString}'
// create custom object
var fslogixCustomObject = 'FSLogix=@([pscustomobject]@{${fslogixString}})'

// Dynamic parameters for the Anti-Malware Extension
var fslogixExclusionsCloudCache = contains(fslogixContainerType, 'CloudCache') ? ';"%ProgramData%\\FSLogix\\Cache\\*";"%ProgramData%\\FSLogix\\Proxy\\*"' : ''

var fslogixSANameMinus2 = [for name in fslogixStorageAccountNames: take(name, length(name)-2)]
var fslogixDedupedSANames = union(fslogixSANameMinus2, fslogixSANameMinus2)
var fslogixMatchPrefix = length(fslogixDedupedSANames) == 1 ? true : false

var fslogixOfficeSharesPrefixMatch = !empty(fslogixDedupedSANames) ? ['\\\\${fslogixDedupedSANames[0]}??.file.${storageSuffix}\\office-containers\\*\\*.VHDX'] : []
var fslogixProfileSharesPrefixMatch = !empty(fslogixDedupedSANames) ? ['\\\\${fslogixDedupedSANames[0]}??.file.${storageSuffix}\\profile-containers\\*\\*.VHDX'] : []

var fslogixOfficeSharesNoMatch = [for name in fslogixStorageAccountNames: '\\\\${name}.file.${storageSuffix}}\\office-containers\\*\\*.VHDX']
var fslogixProfileSharesNoMatch = [for name in fslogixStorageAccountNames: '\\\\${name}.file.${storageSuffix}}\\profile-containers\\*\\*.VHDX']

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
var shcCommonString = 'ActiveDirectorySolution=\'${identitySolution}\';AmdVmSize=\'${amdVmSize}\';nvidiaVmSize=\'${nvidiaVmSize}\';HostPoolRegistrationToken=\'${hostPoolToken}\''
var shcCommonCustomObject = 'SHConfiguration=@([pscustomobject]@{${shcCommonString}})'

// CSE Master Script Dynamic parameters - Built from any custom parameters provided via parameter and the FSLogix and SessionHostConfiguration parameters.
var cseScriptCalculatedParameters = fslogixConfigureSessionHosts ? '${fslogixCustomObject};${shcCommonCustomObject}' : '${shcCommonCustomObject}'
var cseScriptDynamicParameters = empty(cseScriptAddDynParameters) ? '@{${cseScriptCalculatedParameters}}': '@{${cseScriptCalculatedParameters};${cseScriptAddDynParameters}}'
// When sending a hashtable via powershell.exe you must use -command instead of -File in order for the parameter to be interpreted as a hashtable and not a string
var cseCommandToExecute = 'powershell -ExecutionPolicy Unrestricted -Command .\\${cseMasterScript} -DynParameters ${cseScriptDynamicParameters}'

var identityType = (!contains(identitySolution, 'DomainServices') || enableMonitoring ? true : false) ? (!empty(artifactsUserAssignedIdentityResourceId) ? 'SystemAssigned, UserAssigned' : 'SystemAssigned') : (!empty(artifactsUserAssignedIdentityResourceId) ? 'UserAssigned' : 'None')

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
var intune = contains(identitySolution, 'IntuneEnrollment')
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

resource storageAccounts 'Microsoft.Storage/storageAccounts@2023-01-01' existing = [for ResId in fslogixStorageAccountResourceIds: if(fslogixConfigureSessionHosts && !empty(fslogixStorageAccountResourceIds)) {
  name: last(split(ResId, '/'))
  scope: resourceGroup(split(ResId, '/')[2], split(ResId, '/')[4])
}]

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

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' = [for i in range(0, sessionHostCount): {
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
          diskEncryptionSet: securityType != 'ConfidentialVM' && !empty(diskEncryptionSetResourceId) ? {
            id: diskEncryptionSetResourceId
          } : null
          securityProfile: securityType == 'ConfidentialVM' ? {
            diskEncryptionSet: !empty(diskEncryptionSetResourceId) ? {
              id: diskEncryptionSetResourceId
            } : null
            securityEncryptionType: confidentialVMOSDiskEncryptionType
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
      encryptionAtHost: encryptionAtHost
      securityType: !empty(securityType) ? securityType : null
      uefiSettings: !empty(securityType) ? {
        secureBootEnabled: true
        vTpmEnabled: true
      } : null 
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

resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (contains(identitySolution, 'DomainServices')) {
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

resource extension_AADLoginForWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (!contains(identitySolution, 'DomainServices')) {
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

resource extension_IaasAntimalware 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if(environment().name != 'USNAT') {
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
  dependsOn: [
    extension_AADLoginForWindows
    extension_JsonADDomainExtension
  ]
}]

resource extension_AzureMonitorWindowsAgent 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, sessionHostCount): if (enableMonitoring) {
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
    extension_AADLoginForWindows
    extension_JsonADDomainExtension
    extension_IaasAntimalware
  ]
}]

resource dataCollectionEndpointAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for i in range(0, sessionHostCount): if (enableMonitoring && !empty(dataCollectionEndpointResourceId)) {
  scope: virtualMachine[i]
  name: 'configurationAccessEndpoint'
  properties: {
    dataCollectionEndpointId: dataCollectionEndpointResourceId
    description: 'Data Collection Endpoint Association'
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
  ]
}]

resource avdInsightsDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for i in range(0, sessionHostCount): if (enableMonitoring && !empty(avdInsightsDataCollectionRulesResourceId)) {
  scope: virtualMachine[i]
  name: 'avdinsights-${virtualMachine[i].name}-dcra'
  properties: {
    dataCollectionRuleId: avdInsightsDataCollectionRulesResourceId
    description: 'AVD Insights data collection rule association'
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
  ]
}]

resource vmInsightsDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for i in range(0, sessionHostCount): if (enableMonitoring && !empty(vmInsightsDataCollectionRulesResourceId)) {
  scope: virtualMachine[i]
  name: 'vmInsights-${virtualMachine[i].name}-dcra'
  properties: {
    dataCollectionRuleId: vmInsightsDataCollectionRulesResourceId
    description: 'VM Insights data collection rule association'
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

resource extension_MicrosoftMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, sessionHostCount): if (!empty(securityLogAnalyticsWorkspaceResourceId)) {
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
      workspaceId: !empty(securityLogAnalyticsWorkspaceResourceId) ? securityWorkspace.properties.customerId : ''
    }
    protectedSettings: {
      workspaceKey: !empty(securityLogAnalyticsWorkspaceResourceId) ? securityWorkspace.listKeys().primarySharedKey : ''
    }
  }
  dependsOn: [
    extension_IaasAntimalware
    extension_AADLoginForWindows
    extension_JsonADDomainExtension
  ]
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
    extension_IaasAntimalware
    extension_AzureMonitorWindowsAgent
    extension_MicrosoftMonitoringAgent
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
    extension_AzureMonitorWindowsAgent
    extension_MicrosoftMonitoringAgent
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
    extension_AADLoginForWindows
    extension_JsonADDomainExtension
    extension_AmdGpuDriverWindows
    extension_NvidiaGpuDriverWindows
    extension_IaasAntimalware
    extension_AzureMonitorWindowsAgent
    extension_MicrosoftMonitoringAgent
  ]
}]

// Enables drain mode on the session hosts so users cannot login to hosts immediately after the deployment
module setDrainMode '../../../sharedModules/custom/customScriptExtension.bicep' = if (drainMode) {
  name: 'CSE_DrainMode_${batchCount}_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Set-AvdDrainMode.ps1 -Environment ${environment().name} -HostPoolName ${hostPoolName} -HostPoolResourceGroupName ${resourceGroupControlPlane} -SessionHostCount ${sessionHostCount} -SessionHostIndex ${sessionHostIndex} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${drainModeUserAssignedIdentityClientId} -VirtualMachineNamePrefix ${virtualMachineNamePrefix}'
    fileUris: [
      '${artifactsUri}Set-AvdDrainMode.ps1'
    ]
    location: location
    tags: tagsVirtualMachines
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    virtualMachineName: managementVirtualMachineName
  }
  dependsOn: [
    extension_CustomScriptExtension
  ]
}
