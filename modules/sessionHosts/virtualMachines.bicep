param ActiveDirectorySolution string
param ArtifactsLocation string
param ArtifactsUserAssignedIdentityClientId string
param ArtifactsUserAssignedIdentityResourceId string
param AcceleratedNetworking string
param Availability string
param AvailabilitySetNamePrefix string
param AvailabilityZones array
param BatchCount int
param CSEMasterScript string
param CSEUris array
param CSEScriptAddDynParameters string
param DiskEncryptionOptions object
param DiskEncryptionSetResourceId string
param DiskNamePrefix string
param DiskSku string
@secure()
param DomainJoinPassword string
param DomainJoinUserPrincipalName string
param DomainName string
param DrainMode bool
param DrainModeUserAssignedIdentityClientId string
param FslogixConfigureSessionHosts bool
param FslogixSolution string
param FslogixExistingStorageAccountResourceIds array
param HostPoolName string
param ImageOffer string
param ImagePublisher string
param ImageSku string
param ImageVersionResourceId string
param KeyVaultResourceId string
param KeyVaultUrl string
param ADEKEKUrl string
param Location string
param LogAnalyticsWorkspaceName string
param ManagementVMName string
param Monitoring bool
param NetAppFileShares array
param NetworkInterfaceNamePrefix string
param OuPath string
param ResourceGroupControlPlane string
param ResourceGroupManagement string
param ResourceGroupStorage string
param SecurityLogAnalyticsWorkspaceResourceId string
param SessionHostCount int
param SessionHostIndex int
param StorageAccountPrefix string
param StorageCount int
param StorageIndex int
param StorageSolution string
param StorageSuffix string
param Subnet string
param TagsNetworkInterfaces object
param TagsVirtualMachines object
param Timestamp string
param TrustedLaunch string
param VirtualMachineNamePrefix string
@secure()
param VirtualMachinePassword string
param VirtualMachineSize string
param VirtualMachineUsername string
param VirtualNetwork string
param VirtualNetworkResourceGroup string

var AmdVmSize = contains(AmdVmSizes, VirtualMachineSize)
var AmdVmSizes = [
  'Standard_NV4as_v4'
  'Standard_NV8as_v4'
  'Standard_NV16as_v4'
  'Standard_NV32as_v4'
]

var FslogixExclusions = '"%TEMP%\\*\\*.VHDX";"%Windir%\\TEMP\\*\\*.VHDX"${FslogixExclusionsCloudCache}${FslogixExclusionsProfileContainers}${FslogixExclusionsOfficeContainers}'
var FslogixExclusionsCloudCache = contains(FslogixSolution, 'CloudCache') ? ';"%ProgramData%\\FSLogix\\Cache\\*";"%ProgramData%\\FSLogix\\Proxy\\*"' : ''
var FslogixOfficeShare = '\\\\${StorageAccountPrefix}??.file.${StorageSuffix}\\office-containers\\*\\*.VHDX'
var FslogixProfileShare = '\\\\${StorageAccountPrefix}??.file.${StorageSuffix}\\profile-containers\\*\\*.VHDX'
var FslogixExclusionsOfficeContainers = contains(FslogixSolution, 'Office') ? ';"${FslogixOfficeShare}";"${FslogixOfficeShare}.lock";"${FslogixOfficeShare}.meta";"${FslogixOfficeShare}.metadata"' : ''
var FslogixExclusionsProfileContainers = ';"${FslogixProfileShare}";"${FslogixProfileShare}.lock";"${FslogixProfileShare}.meta";"${FslogixProfileShare}.metadata"'

// Dynamic Parameters for Configure-FSLogix Script
//  cloudcache determined from FslogixSolution parameter
var FslogixCloudCacheString = contains(FslogixSolution, 'CloudCache') ? 'cloudCache=$true' : 'cloudCache=$false'
//  convert long ActiveDirectorySolution parameter values to short and SMB authentication specific values for script.
var FslogixIdP = contains(ActiveDirectorySolution, 'Kerberos') ? 'AADKERB' : !contains(ActiveDirectorySolution, 'DomainServices') ? 'AAD' : 'DomainServices'
var FslogixIdpString = 'idp=\'${FslogixIdP}\''
var FslogixStorageSolutionString = 'storageSolution=\'${StorageSolution}\''
var FslogixNetAppSharesString = StorageSolution == 'AzureNetAppFiles' && NetAppFileShares != 'None' ? 'NetAppFileShares=\'${replace(join(NetAppFileShares, ','), ',', '\',\'')}\'' : ''
var FslogixSASuffixString = StorageSolution == 'AzureFiles' ? 'saSuffix=\'${StorageSuffix}\'' : ''
//  build storage account names from Storage Account parameters.
var FslogixNewSANames = [for i in range(0, StorageCount): '${StorageAccountPrefix}${padLeft(i + StorageIndex, 2, '0')}']
//  use only first storage account per region with AAD and Storage Key. No sharding possible.
var FslogixNewStorageNames = FslogixIdP == 'AAD' ? [FslogixNewSANames[0]] : FslogixNewSANames
var FslogixExistingSANames = [for resourceId in FslogixExistingStorageAccountResourceIds: last(split(resourceId, '/')) ]
var FslogixExistingStorageNames  = FslogixIdP == 'AAD' && !empty(FslogixExistingStorageAccountResourceIds) ? [FslogixExistingSANames[0]] : FslogixExistingSANames
var FslogixSANamesString = StorageSolution == 'AzureFiles' ? 'saNames=\'${replace(join(union(FslogixNewStorageNames, FslogixExistingStorageNames), ','), ',', '\',\'')}\'' : ''
//  get only the first storage account key per region with AAD and Storage Key. No sharding possible.
var FslogixSAKey = FslogixIdP == 'AAD' ? [ storageAccounts[0].listKeys().keys[0].value ] : []
var FslogixHASAKey = FslogixIdP == 'AAD' && !empty(FslogixExistingStorageAccountResourceIds) ? [ existingStorageAccountsforHA.listKeys().keys[0].value ] : []
var FslogixSAKeysString = FslogixIdP == 'AAD' ? 'saKeys=\'${replace(join(union(FslogixSAKey, FslogixHASAKey), ','), ',', '\',\'')}\'' : ''
var FslogixSharesString = StorageSolution != 'AzureNetAppFiles' ? contains(FslogixSolution, 'Office') ? 'shareNames=\'profile-containers\',\'office-containers\'' : 'shareNames=\'profile-containers\'' : ''
var FslogixCommon = '${FslogixIdpString};${FslogixStorageSolutionString};${FslogixCloudCacheString}'
var FslogixString = StorageSolution == 'AzureNetAppFiles' ? '${FslogixCommon};${FslogixNetAppSharesString}' : FslogixIdP == 'AAD' ? '${FslogixCommon};${FslogixSASuffixString};${FslogixSANamesString};${FslogixSAKeysString};${FslogixSharesString}' : '${FslogixCommon};${FslogixSASuffixString};${FslogixSANamesString};${FslogixSharesString}'
var FslogixCustomObject = 'FSLogix=@([pscustomobject]@{${FslogixString}})'

// Dynamic Parameters for Set-SessionHostConfiguration.ps1
//var HostPoolToken = hostPool.properties.registrationInfo.token
var HostPoolToken = reference(resourceId(ResourceGroupControlPlane, 'Microsoft.DesktopVirtualization/hostpools', HostPoolName), '2019-12-10-preview').registrationInfo.token
var SHCCommon = 'ActiveDirectorySolution=\'${ActiveDirectorySolution}\';AmdVmSize=\'${AmdVmSize}\';NvidiaVmSize=\'${NvidiaVmSize}\';HostPoolRegistrationToken=\'${HostPoolToken}\''
var SHCString = SecurityMonitoring ? '${SHCCommon};SecurityWorkspaceId=\'${logAnalyticsWorkspace.properties.customerId}\';SecurityWorkspaceKey=\'${SecurityWorkspaceKey}\'' : SHCCommon
var SHCCustomObject = 'SHConfiguration=@([pscustomobject]@{${SHCString}})'

// CSE Master Script Dynamic Parameters - Built from any custom parameters provided via parameter and the FSLogix and SessionHostConfiguration Parameters.
var CSEScriptCalculatedParameters = FslogixConfigureSessionHosts ? '${FslogixCustomObject};${SHCCustomObject}' : '${SHCCustomObject}'
var CSEScriptDynamicParameters = empty(CSEScriptAddDynParameters) ? '@{${CSEScriptCalculatedParameters}}': '@{${CSEScriptCalculatedParameters};${CSEScriptAddDynParameters}}'
// When sending a hashtable via powershell.exe you must use -command instead of -File in order for the parameter to be interpreted as a hashtable and not a string
var CSECommandToExecute = 'powershell -ExecutionPolicy Unrestricted -Command .\\${CSEMasterScript} -DynParameters ${CSEScriptDynamicParameters}'

var IdentityType = (!contains(ActiveDirectorySolution, 'DomainServices') ? true : false) ? (!empty(ArtifactsUserAssignedIdentityResourceId) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(ArtifactsUserAssignedIdentityResourceId) ? 'UserAssigned' : 'None')

var UserAssignedIdentities = !empty(ArtifactsUserAssignedIdentityResourceId) ? {
  '${ArtifactsUserAssignedIdentityResourceId}': {}
} : {}

var Identity = IdentityType != 'None' ? {
  type: IdentityType
  userAssignedIdentities: !empty(UserAssignedIdentities) ? UserAssignedIdentities : null
} : null

var ImageReference = empty(ImageVersionResourceId) ? {
  publisher: ImagePublisher
  offer: ImageOffer
  sku: ImageSku
  version: 'latest'
} : {
  id: ImageVersionResourceId
}
var Intune = contains(ActiveDirectorySolution, 'IntuneEnrollment')
var NvidiaVmSize = contains(NvidiaVmSizes, VirtualMachineSize)
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
var SecurityLogAnalyticsWorkspaceName = SecurityMonitoring ? split(SecurityLogAnalyticsWorkspaceResourceId, '/')[8] : ''
var SecurityLogAnalyticsWorkspaceResourceGroupName = SecurityMonitoring ? split(SecurityLogAnalyticsWorkspaceResourceId, '/')[4] : resourceGroup().name
var SecurityLogAnalyticsWorkspaceSubscriptionId = SecurityMonitoring ? split(SecurityLogAnalyticsWorkspaceResourceId, '/')[2] : subscription().subscriptionId
var SecurityMonitoring = empty(SecurityLogAnalyticsWorkspaceResourceId) ? false : true
var SecurityWorkspaceKey = SecurityMonitoring ? listKeys(SecurityLogAnalyticsWorkspaceResourceId, '2021-06-01').primarySharedKey : 'NotApplicable'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = if (SecurityMonitoring) {
  name: SecurityLogAnalyticsWorkspaceName
  scope: resourceGroup(SecurityLogAnalyticsWorkspaceSubscriptionId, SecurityLogAnalyticsWorkspaceResourceGroupName)
}

// call on new storage accounts only if we need the Storage Key(s)
resource storageAccounts 'Microsoft.Storage/storageAccounts@2023-01-01' existing = [for i in range(0, StorageCount): if (StorageSolution == 'AzureFiles' && !contains(ActiveDirectorySolution, 'Kerberos') && !contains(ActiveDirectorySolution, 'DomainServices')) {
  name: '${StorageAccountPrefix}${padLeft(i + StorageIndex, 2, '0')}'
  scope: resourceGroup(ResourceGroupStorage)
}]

resource existingStorageAccountsforHA 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (StorageSolution == 'AzureFiles' && !contains(ActiveDirectorySolution, 'Kerberos') && !contains(ActiveDirectorySolution, 'DomainServices')){
  name: last(split(FslogixExistingStorageAccountResourceIds[0], '/'))
  scope: resourceGroup(split(FslogixExistingStorageAccountResourceIds[0], '/')[2], split(FslogixExistingStorageAccountResourceIds[0], '/')[4])
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2020-05-01' = [for i in range(0, SessionHostCount): {
  name: '${NetworkInterfaceNamePrefix}${padLeft((i + SessionHostIndex), 3, '0')}'
  location: Location
  tags: TagsNetworkInterfaces
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(subscription().subscriptionId, VirtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', VirtualNetwork, Subnet)
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

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, SessionHostCount): {
  name: '${VirtualMachineNamePrefix}${padLeft((i + SessionHostIndex), 3, '0')}'
  location: Location
  tags: TagsVirtualMachines
  zones: Availability == 'AvailabilityZones' ? [
    AvailabilityZones[i % length(AvailabilityZones)]
  ] : null
  identity: Identity
  properties: {
    availabilitySet: Availability == 'AvailabilitySets' ? {
      id: resourceId('Microsoft.Compute/availabilitySets', '${AvailabilitySetNamePrefix}-${(i + SessionHostIndex) / 200}')
    } : null
    hardwareProfile: {
      vmSize: VirtualMachineSize
    }
    storageProfile: {
      imageReference: ImageReference
      osDisk: {
        name: '${DiskNamePrefix}${padLeft((i + SessionHostIndex), 3, '0')}'
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
        managedDisk: {
          diskEncryptionSet: DiskEncryptionOptions.DiskEncryptionSet ? {
            id: DiskEncryptionSetResourceId
          } : null
          storageAccountType: DiskSku
        }
      }
      dataDisks: []
    }
    osProfile: {
      computerName: '${VirtualMachineNamePrefix}${padLeft((i + SessionHostIndex), 3, '0')}'
      adminUsername: VirtualMachineUsername
      adminPassword: VirtualMachinePassword
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
          id: resourceId('Microsoft.Network/networkInterfaces', '${NetworkInterfaceNamePrefix}${padLeft((i + SessionHostIndex), 3, '0')}')
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: {
      uefiSettings: TrustedLaunch == 'true' ? {
        secureBootEnabled: true
        vTpmEnabled: true
      } : null
      securityType: TrustedLaunch == 'true' ? 'TrustedLaunch' : null
      encryptionAtHost: DiskEncryptionOptions.EncryptionAtHost
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    licenseType: ((ImagePublisher == 'MicrosoftWindowsDesktop') ? 'Windows_Client' : 'Windows_Server')
  }
  dependsOn: [
    networkInterface
  ]
}]

resource extension_IaasAntimalware 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, SessionHostCount): {
  parent: virtualMachine[i]
  name: 'IaaSAntimalware'
  location: Location
  tags: TagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
    settings: {
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: 'true'
      ScheduledScanSettings: {
        isEnabled: 'true'
        day: '7' // Day of the week for scheduled scan (1-Sunday, 2-Monday, ..., 7-Saturday)
        time: '120' // When to perform the scheduled scan, measured in minutes from midnight (0-1440). For example: 0 = 12AM, 60 = 1AM, 120 = 2AM.
        scanType: 'Quick' //Indicates whether scheduled scan setting type is set to Quick or Full (default is Quick)
      }
      Exclusions: FslogixConfigureSessionHosts ? {
        Paths: FslogixExclusions
      } : {}
    }
  }
}]

resource extension_MicrosoftMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, SessionHostCount): if (Monitoring) {
  parent: virtualMachine[i]
  name: 'MicrosoftMonitoringAgent'
  location: Location
  tags: TagsVirtualMachines
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: Monitoring ? reference(resourceId(ResourceGroupManagement, 'Microsoft.OperationalInsights/workspaces', LogAnalyticsWorkspaceName), '2015-03-20').customerId : null
    }
    protectedSettings: {
      workspaceKey: Monitoring ? listKeys(resourceId(ResourceGroupManagement, 'Microsoft.OperationalInsights/workspaces', LogAnalyticsWorkspaceName), '2015-03-20').primarySharedKey : null
    }
  }
  dependsOn: [
    extension_IaasAntimalware
  ]
}]

resource extension_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, SessionHostCount): {
  parent: virtualMachine[i]
  name: 'CustomScriptExtension'
  location: Location
  tags: TagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: CSEUris
      timestamp: Timestamp
    }    
    protectedSettings: contains(ArtifactsLocation, environment().suffixes.storage) ? {
      commandToExecute: CSECommandToExecute
      managedIdentity: { clientId: ArtifactsUserAssignedIdentityClientId }
    } : {
      commandToExecute: CSECommandToExecute
    }
  }
  dependsOn: [
    extension_MicrosoftMonitoringAgent
  ]
}]

// Enables drain mode on the session hosts so users cannot login to hosts immediately after the deployment
module drainMode '../management/customScriptExtensions.bicep' = if (DrainMode) {
  name: 'CSE_DrainMode_${BatchCount}_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    ArtifactsLocation: ArtifactsLocation
    Files: ['Set-AvdDrainMode.ps1']
    ExecuteScript: 'Set-AvdDrainMode.ps1'
    Location: Location
    Parameters: '-Environment ${environment().name} -HostPoolName ${HostPoolName} -HostPoolResourceGroupName ${ResourceGroupControlPlane} -SessionHostCount ${SessionHostCount} -SessionHostIndex ${SessionHostIndex} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${DrainModeUserAssignedIdentityClientId} -VirtualMachineNamePrefix ${VirtualMachineNamePrefix}'
    Tags: TagsVirtualMachines
    UserAssignedIdentityClientId: ArtifactsUserAssignedIdentityClientId
    VirtualMachineName: ManagementVMName
  }
  dependsOn: [
    extension_CustomScriptExtension
  ]
}

resource extension_AzureDiskEncryption 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [for i in range(0, SessionHostCount): if (DiskEncryptionOptions.AzureDiskEncryption) {
  parent: virtualMachine[i]
  name: 'AzureDiskEncryption'
  location: Location
  tags: TagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'AzureDiskEncryption'
    typeHandlerVersion: '2.2'
    autoUpgradeMinorVersion: true
    settings: {
      EncryptionOperation: 'EnableEncryption'
      KeyEncryptionAlgorith: 'RSA-OAEP-256'
      KeyVaultURL: KeyVaultUrl
      KeyVaultResourceId: KeyVaultResourceId
      KeyEncryptionKeyUrl: DiskEncryptionOptions.KeyEncryptionKey ? ADEKEKUrl : null
      VolumeType: 'All'
    }
  }
}]

resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, SessionHostCount): if (contains(ActiveDirectorySolution, 'DomainServices')) {
  parent: virtualMachine[i]
  name: 'JsonADDomainExtension'
  location: Location
  tags: TagsVirtualMachines
  properties: {
    forceUpdateTag: Timestamp
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: DomainName
      User: DomainJoinUserPrincipalName
      Restart: 'true'
      Options: '3'
      OUPath: OuPath
    }
    protectedSettings: {
      Password: DomainJoinPassword
    }
  }
  dependsOn: [
    drainMode
  ]
}]

resource extension_AADLoginForWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, SessionHostCount): if (!contains(ActiveDirectorySolution, 'DomainServices')) {
  parent: virtualMachine[i]
  name: 'AADLoginForWindows'
  location: Location
  tags: TagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: Intune ? {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    } : null
  }
  dependsOn: [
    drainMode
  ]
}]

resource extension_AmdGpuDriverWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, SessionHostCount): if (AmdVmSize) {
  parent: virtualMachine[i]
  name: 'AmdGpuDriverWindows'
  location: Location
  tags: TagsVirtualMachines
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

resource extension_NvidiaGpuDriverWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, SessionHostCount): if (NvidiaVmSize) {
  parent: virtualMachine[i]
  name: 'NvidiaGpuDriverWindows'
  location: Location
  tags: TagsVirtualMachines
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

output CSECommandToExecute string = CSECommandToExecute
