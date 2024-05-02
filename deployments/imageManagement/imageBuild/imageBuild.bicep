targetScope = 'subscription'

metadata name = 'Zero Trust Architecture Custom Windows Image Builder'
metadata description = 'This solution allows you to create a custom image much like Azure VM Image Builder, but utilizes zero trust architecture and does not require that service.'
metadata author = 'shawn.meyer@microsoft.com'
metadata version = '1.0.0'

@description('Deployment location. Note that the compute resources will be deployed to the region where the subnet is location.')
param deploymentLocation string = deployment().location

@description('Value to prepend to the deployment names.')
@maxLength(6)
param deploymentPrefix string = ''

@description('Value appended to the deployment names.')
param timeStamp string = utcNow('yyMMddHHmm')

@description('The current time in ISO 8601 format. Do not modify.')
param imageVersionCreationTime string = utcNow()

param guidValue string = newGuid()

@description('The name of the blob that contains the Az module installer.')
param azModuleBlobName string = 'PowerShell-Az.msi'

@allowed([
  'dev'
  'test'
  'prod'
  ''
])
@description('Optional. The environment for which the images are being created.')
param envClassification string = ''

// Required Existing Resources
@description('Azure Compute Gallery Resource Id.')
param computeGalleryResourceId string

@description('The resource Id of the storage account containing the artifacts (scripts, installers, etc) used during the image build.')
param storageAccountResourceId string

@description('The name of the storage blob container which contains the artifacts (scripts, installers, etc) used during the image build.')
param containerName string

@description('The resource Id of the user assigned managed identity used to access the storage account.')
param userAssignedIdentityResourceId string

@description('The resource Id of the subnet to which the image build VM will be attached.')
param subnetResourceId string

@description('The resource Id of an existing resource group in which to create the vms to build the image. Leave blank to create a new resource group.')
param imageBuildResourceGroupId string = ''

// Optional Custom Naming
@description('The custom name of the resource group where the image build and management vms will be created. Leave blank to create a new resource group based on Cloud Adoption Framework naming principals.')
param customBuildResourceGroupName string = ''

// Source Image Properties

@description('Optional. The resource Id of the source image to use for the image build. If not provided, the latest image from the specified publisher, offer, and sku will be used.')
param customSourceImageResourceId string = ''

@description('The Marketplace Image publisher')
param publisher string

@description('The Marketplace Image offer')
param offer string

@description('The Marketplace Image sku')
param sku string

@description('Optional. Determines if "EncryptionAtHost" is enabled on the VMs.')
param encryptionAtHost bool = true

@description('The size of the Image build and Management VMs.')
param vmSize string

// Image customizers
@description('Optional. Install FSLogix Agent.')
param installFsLogix bool = false

@description('Conditional. The name of the blob that contains the FSlogix zip.')
param fslogixBlobName string = 'FSLogix.zip'

@description('Optional. Install Microsoft Access.')
param installAccess bool = false

@description('Optional. Install Microsoft Excel.')
param installExcel bool = false

@description('Optional. Install OneDrive Per Machine.')
param installOneDrive bool = false

@description('Conditional. The name of the blob containing OneDriveSetup.exe.')
param onedriveBlobName string = 'OneDriveSetup.exe'

@description('Optional. Install Microsoft OneNote.')
param installOneNote bool = false

@description('Optional. Install Microsoft Outlook.')
param installOutlook bool = false

@description('Optional. Install Microsoft PowerPoint.')
param installPowerPoint bool = false

@description('Optional. Install Microsoft Project.')
param installProject bool = false

@description('Optional. Install Microsoft Publisher.')
param installpublisher bool = false

@description('Optional. Install Microsoft Skype for Business.')
param installSkypeForBusiness bool = false

@description('Optional. Install Microsoft Visio.')
param installVisio bool = false

@description('Optional. Install Microsoft Word.')
param installWord bool = false

@description('Optional. The name of the blob containing the Office Deployment Tool.')
param officeBlobName string = 'Office365DeploymentTool.exe'

@description('Optional. Install Microsoft Teams.')
param installTeams bool = false

@description('Optional. The name of the zip blob containing the VC++Redistributables, MSRDC WebRTC Redirector, and Teams installer.')
@allowed(['Classic', 'New'])
param teamsVersion string = 'Classic'

@description('Optional. Apply the Virtual Desktop Optimization Tool customizations.')
param installVirtualDesktopOptimizationTool bool = false

@description('Conditional. The name of the zip blob containing the Virtual Desktop Optimization Tool Script and files.')
param vDotBlobName string = 'VDOT.zip'

@description('''An array of image customizations consisting of the blob name and parameters.
BICEP example:
[
  {
    name: 'FSLogix'
    blobName: 'Install-FSLogix.zip'
    arguments: 'latest'
  }
  {
    name: 'VSCode'
    blobName: 'VSCode.zip'
    arguments: ''
  }
]
''')
param customizations array = []

@description('Optional. Collect image customization logs.')
param collectCustomizationLogs bool = false

@description('Optional. Determines if the latest updates from the specified update service will be installed.')
param installUpdates bool = true

@allowed([
  'WU'
  'MU'
  'WSUS'
  'DCAT'
  'STORE'
  'OTHER'
])
@description('Optional. The update service.')
param updateService string = 'MU'

@description('Conditional. The WSUS Server Url if WSUS is specified. (i.e., https://wsus.corp.contoso.com:8531)')
param wsusServer string = ''

@description('''Conditional. The resource id of the existing Azure storage account blob service private dns zone.
Must be provided if [collectCustomizationLogs] is set to "true".
This zone must be linked to or resolvable from the vnet referenced in the [privateEndpointSubnetResourceId] parameter.''')
param blobPrivateDnsZoneResourceId string = ''

@description('Conditional. The resource id of the private endpoint subnet. Must be provided if [collectCustomizationLogs] is set to "true".')
param privateEndpointSubnetResourceId string = ''

// Output Image properties

// Optional Existing Resource
@description('Optional. The resource id of an existing Image Definition in the Compute gallery.')
param imageDefinitionResourceId string = ''

@description('''Conditional. The name of the image Definition to create in the Compute Gallery.
Only valid if [imageDefinitionResourceId] is not provided.
If left blank, the image definition name will be built on Cloud Adoption Framework principals and based on the [imageDefinitonPublisher], [imageDefinitionOffer], and [imageDefinitionSku] values.''')
@maxLength(80)
param customImageDefinitionName string = ''

@description('Conditional. The compute gallery image definition Publisher.')
@maxLength(128)
param imageDefinitionPublisher string = ''

@description('Conditional. The computer gallery image definition Offer.')
@maxLength(64)
param imageDefinitionOffer string = ''

@description('Conditional. The compute gallery image definition Sku.')
@maxLength(64)
param imageDefinitionSku string = ''

@description('Optional. Specifies whether the image definition supports the deployment of virtual machines with accelerated networking enabled.')
param imageDefinitionIsAcceleratedNetworkSupported bool = false

@description('Optional. Specifies whether the image definition supports creating VMs with support for hibernation.')
param imageDefinitionIsHibernateSupported bool = false

@description('Optional. Specifies whether the image definition supports capturing images of NVMe disks or Virtual Machines.')
param imageDefinitionIsHigherStoragePerformanceSupported bool = false

@allowed([
  'Standard'
  'ConfidentialVM'
  'ConfidentialVMSupported'
  'TrustedLaunch'
  'TrustedLaunchSupported'
  'TrustedLaunchAndConfidentialVMSupported'
])
param imageDefinitionSecurityType string = 'TrustedLaunch'

@description('Automatically generated Image Version name.')
param autoImageVersionName string = utcNow('yy.MMdd.hhmm')

@description('''Optional. The image major version from 0 - 9999.
In order to specify a custom image version you must specify the [imageMajorVersion], [imageMinorVersion], and [imagePatch] integer from 0-9999.''')
@minValue(-1)
@maxValue(9999)
param imageMajorVersion int = -1

@description('''Optional. The image minor version from 0 - 9999.
In order to specify a custom image version you must specify the [imageMajorVersion], [imageMinorVersion], and [imagePatch] integer from 0-9999.''')
@minValue(-1)
@maxValue(9999)
param imageMinorVersion int = -1

@description('''Optional. The image patch version from 0 - 9999.
In order to specify a custom image version you must specify the [imageMajorVersion], [imageMinorVersion], and [imagePatch] integer from 0-9999.''')
@minValue(-1)
@maxValue(9999)
param imagePatch int = -1

@description('Optional. The number of days from now that the image version will reach end of life.')
param imageVersionEOLinDays int = 0

@description('Optional. The default image version replica count per region. This can be overwritten by the regional value.')
@minValue(1)
@maxValue(100)
param imageVersionDefaultReplicaCount int = 1

@description('Optional. Specifies the storage account type to be used to store the image. This property is not updatable.')
@allowed([
  'Premium_LRS'
  'Standard_LRS'
  'Standard_ZRS'
])
param imageVersionDefaultStorageAccountType string = 'Standard_LRS'

@description('Conditional. Specifies the default replication region when imageVersionTargetRegions is not supplied.')
param imageVersionDefaultRegion string = ''

@description('Optional. Exclude this image version from the latest. This property can be overwritten by the regional value.')
param imageVersionExcludeFromLatest bool = false

@description('Optional. The regions to which the image version will be replicated. (Default: deployment location with Standard_LRS storage and 1 replica.)')
param imageVersionTargetRegions array = []

@description('Optional. The tags to apply to all resources deployed by this template.')
param tags object = {}

// * VARIABLE DECLARATIONS * //

var teamsBlobName = teamsVersion == 'Classic' ? 'Microsoft-Teams-Classic.zip' : 'Microsoft-Teams.zip'
var installers = []

var customizers = union(customizations, installers)

var cloud = environment().name
var subscriptionId = subscription().subscriptionId
var tenantId = tenant().tenantId
var locations = loadJsonContent('../../../.common/data/locations.json')[environment().name]
var resourceAbbreviations = loadJsonContent('../../../.common/data/resourceAbbreviations.json')

var computeLocation = vnet.location
var depPrefix = !empty(deploymentPrefix) ? '${deploymentPrefix}-' : ''

var imageBuildResourceGroupName = empty(imageBuildResourceGroupId) ? (empty(customBuildResourceGroupName) ? (!empty(envClassification) ? '${resourceAbbreviations.resourceGroups}-image-builder-${envClassification}-${locations[deploymentLocation].abbreviation}' : '${resourceAbbreviations.resourceGroups}-image-builder-${locations[deploymentLocation].abbreviation}') : customBuildResourceGroupName) : last(split(imageBuildResourceGroupId, '/'))

var adminPw = '${toUpper(uniqueString(subscription().id))}-${guidValue}'
var adminUserName = 'xadmin'
var securityType = galleryImageDefinitionSecurityType == 'TrustedLaunch' || galleryImageDefinitionSecurityType == 'ConfidentialVM' ? galleryImageDefinitionSecurityType : 'Standard'
var artifactsContainerUri = '${artifactsStorageAccount.properties.primaryEndpoints.blob}${containerName}/'

var cseScriptCommonParameters = '-environment ${cloud} -subscription ${subscriptionId} -tenant ${tenantId} -userAssignedIdentityClientId ${managedIdentity.properties.clientId}'
var validationScriptExDefParameters = '${cseScriptCommonParameters} -imageDefinitionResourceId ${imageDefinitionResourceId} -SourceSku ${sku}'
var validationScriptNewDefParameters = '${cseScriptCommonParameters} -imageGalleryResourceId ${computeGalleryResourceId} -imageLocation ${deploymentLocation} -imageName ${galleryImageDefinitionName} -ImageHyperVGeneration ${galleryImageDefinitionHyperVGeneration} -ImageSecurityType ${imageDefinitionSecurityType} -ImageIsHibernateSupported ${imageDefinitionIsHibernateSupported} -ImageIsAcceleratedNetworkSupported ${imageDefinitionIsAcceleratedNetworkSupported} -ImageIsHigherStoragePerformanceSupported ${imageDefinitionIsHigherStoragePerformanceSupported} -imagePublisher ${galleryImageDefinitionPublisher} -imageOffer ${galleryImageDefinitionOffer} -imageSku ${galleryImageDefinitionSku}'

var collectLogs = collectCustomizationLogs && !empty(privateEndpointSubnetResourceId) && !empty(blobPrivateDnsZoneResourceId) ? true : false
var logContainerName = 'image-customization-logs'
var logContainerUri = collectLogs ? '${logsStorageAccount.outputs.primaryBlobEndpoint}${logContainerName}/' : ''

var galleryImageDefinitionPublisher = !empty(imageDefinitionPublisher) ? replace(imageDefinitionPublisher, ' ', '') : publisher
var galleryImageDefinitionOffer = !empty(imageDefinitionOffer) ? replace(imageDefinitionOffer, ' ', '') : offer
var galleryImageDefinitionSku = !empty(imageDefinitionSku) ? replace(imageDefinitionSku, ' ', '') : sku
var galleryImageDefinitionHyperVGeneration = endsWith(sku, 'g2') || startsWith(sku, 'win11') ? 'V2' : 'V1'
var galleryImageDefinitionSecurityType = empty(imageDefinitionResourceId) ? imageDefinitionSecurityType : imageDefinitionValidation.outputs.value.securityType
var galleryImageDefinitionName = empty(imageDefinitionResourceId) ? (empty(customImageDefinitionName) ? '${replace('${resourceAbbreviations.imageDefinitions}-${replace(galleryImageDefinitionPublisher, '-', '')}-${replace(galleryImageDefinitionOffer, '-', '')}-${replace(galleryImageDefinitionSku, '-', '')}', ' ', '')}' : customImageDefinitionName) : last(split(imageDefinitionResourceId, '/'))

var imageVersionName = imageMajorVersion != -1 && imageMajorVersion != -1 && imagePatch != -1 ? '${imageMajorVersion}.${imageMinorVersion}.${imagePatch}' : autoImageVersionName

var imageVersionEndOfLifeDate = imageVersionEOLinDays > 0 ? dateTimeAdd(imageVersionCreationTime, 'P${imageVersionEOLinDays}D') : ''

var imageVersionReplicationRegions = !empty(imageVersionTargetRegions) ? imageVersionTargetRegions : [
  {
    excludeFromLatest: imageVersionExcludeFromLatest
    name: !empty(imageVersionDefaultRegion) ? imageVersionDefaultRegion : deploymentLocation
    regionalReplicaCount: imageVersionDefaultReplicaCount
    storageAccountType: imageVersionDefaultStorageAccountType
  }
]

var imageVmName = take('vmimg-${uniqueString(timeStamp)}', 15)
var managementVmName = take('vmmgt-${uniqueString(timeStamp)}', 15)

var validationScriptParameters = !empty(imageDefinitionResourceId) ? validationScriptExDefParameters : validationScriptNewDefParameters
var getImageVersionSourceParameters = !empty(imageDefinitionResourceId) ? '${cseScriptCommonParameters} -ImageDefinitionResourceId "${imageDefinitionResourceId}" -VmName ${imageVm.outputs.name} -ResourceGroupName ${imageBuildRg.name} -Location ${deploymentLocation}' : '${cseScriptCommonParameters} -ImageDefinitionResourceId "${imageDefinition.outputs.resourceId}" -VmName ${imageVm.outputs.name} -ResourceGroupName ${imageBuildRg.name} -Location ${deploymentLocation}'

// * RESOURCES * //

resource artifactsStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  scope: resourceGroup(split(storageAccountResourceId, '/')[2], split(storageAccountResourceId, '/')[4])
  name: last(split(storageAccountResourceId, '/'))
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(split(userAssignedIdentityResourceId, '/')[2], split(userAssignedIdentityResourceId, '/')[4])
  name: last(split(userAssignedIdentityResourceId, '/'))
}

resource imageBuildRg 'Microsoft.Resources/resourceGroups@2023-07-01' = if(empty(imageBuildResourceGroupId)) {
  name: imageBuildResourceGroupName
  location: deploymentLocation
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: split(subnetResourceId, '/')[8]
  scope: resourceGroup(split(subnetResourceId, '/')[2], split(subnetResourceId, '/')[4])
}

module roleAssignmentContributorBuildRg '../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = {
  name: '${depPrefix}RoleAssign-MI-Contributor-BuildRG-${timeStamp}'
  scope: resourceGroup(imageBuildRg.name)
  params: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' //Contributor
  }
}

module roleAssignmentReaderGalleryRg '../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = {
  name: '${depPrefix}RoleAssign-MI-Reader-GalleryRG-${timeStamp}'
  scope: resourceGroup(split(computeGalleryResourceId, '/')[2], split(computeGalleryResourceId, '/')[4])
  params: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' //Reader
  }
}

module managementVm '../../sharedModules/resources/compute/virtual-machine/main.bicep' = {
  name: '${depPrefix}Management-VM-${timeStamp}'
  scope: resourceGroup(imageBuildRg.name)
  params: {
    location: computeLocation
    name: managementVmName
    adminPassword: adminPw
    adminUsername: adminUserName
    encryptionAtHost: encryptionAtHost
    extensionCustomScriptConfig: {
      enabled: true
      fileData: [
        {
          uri: '${artifactsContainerUri}${azModuleBlobName}'
        }
      ]
    }
    extensionCustomScriptProtectedSetting: {
      commandToExecute: 'msiexec.exe /i ${azModuleBlobName} /quiet /qn /norestart /passive'
      managedIdentity: {
        clientId: managedIdentity.properties.clientId
      }
    }

    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2019-datacenter-core-g2'
      version: 'latest'
    }
    nicConfigurations: [
      {
        deleteOption: 'Delete'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: subnetResourceId
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'None'
      createOption: 'fromImage'
      deleteOption: 'Delete'
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    tags: tags
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
    vmSize: vmSize
  }
}

module imageDefinitionValidation '../../sharedModules/custom/customScriptExtension.bicep' = {
  name: '${depPrefix}Image-Definition-Validation-${timeStamp}'
  scope: resourceGroup(imageBuildRg.name)
  params: {
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Get-ImageBuildValidations.ps1 ${validationScriptParameters}'
    fileUris: [
      '${artifactsContainerUri}Get-ImageBuildValidations.ps1'
    ]
    location: computeLocation
    output: true
    userAssignedIdentityClientId: managedIdentity.properties.clientId
    virtualMachineName: managementVm.outputs.name
  }
  dependsOn: [
    roleAssignmentReaderGalleryRg
  ]
}

module logsStorageAccount '../../sharedModules/resources/storage/storage-account/main.bicep' = if(collectLogs) {
  name: '${depPrefix}Logs-StorageAccount-${timeStamp}'
  scope: resourceGroup(imageBuildRg.name)
  params: {
    name: 'sa${deploymentPrefix}log${uniqueString(subscription().id,imageBuildRg.name,depPrefix)}'
    location: computeLocation
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    requireInfrastructureEncryption: true
    blobServices: {
      containers: [
        {
          name: logContainerName
          publicAccess: 'None'
        }
      ]
    }
    kind: 'StorageV2'
    managementPolicyRules: [
      {
        enabled: true
        name: 'Delete Blobs after 7 days'
        type: 'Lifecycle'
        definition: {
          actions: {
            baseBlob: {
              delete: {
                daysAfterModificationGreaterThan: 7
              }
            }
          }
          filters: {
            blobTypes: [
              'blockBlob'
              'appendBlob'
            ]
          }
        }
      }
    ]
    privateEndpoints: [
      {
        name: 'pe-sa${deploymentPrefix}log${uniqueString(subscription().id,imageBuildRg.name,depPrefix)}-blob-${locations[computeLocation].abbreviation}'
        privateDnsZoneGroup: {
          privateDNSResourceIds: ['${blobPrivateDnsZoneResourceId}']
        }
        service: 'blob'
        subnetResourceId: privateEndpointSubnetResourceId
        tags: tags
      }
    ]
    publicNetworkAccess: 'Disabled'
    sasExpirationPeriod: '180.00:00:00'
    skuName: 'Standard_LRS'
    tags: tags
  }
  dependsOn: [
    imageDefinitionValidation
  ]
}

module roleAssignmentBlobDataContributorBuilderRg '../../sharedModules/resources/authorization/role-assignment/resource-group/main.bicep' = if (collectLogs) {
  name: '${depPrefix}RoleAssign-MI-BlobDataContr-BuildRG-${timeStamp}'
  scope: resourceGroup(imageBuildRg.name)
  params: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
  }  
}

module imageVm '../../sharedModules/resources/compute/virtual-machine/main.bicep' = {
  name: '${depPrefix}Image-VM-${timeStamp}'
  scope: resourceGroup(imageBuildRg.name)
  params: {
    location: computeLocation
    name: imageVmName
    adminPassword: adminPw
    adminUsername: adminUserName
    bootDiagnostics: false
    encryptionAtHost: encryptionAtHost
    imageReference: empty(customSourceImageResourceId) ? {
      publisher: publisher
      offer: offer
      sku: sku
      version: 'latest'
    } : {
      id: customSourceImageResourceId
    }
    nicConfigurations: [
      {
        enabledAcceleratedNetworking: imageDefinitionIsAcceleratedNetworkSupported
        deleteOption: 'Delete'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: subnetResourceId
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'None'
      createOption: 'fromImage'
      deleteOption: 'Delete'
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    securityType: securityType
    secureBootEnabled: securityType == 'TrustedLaunch' ? true : false
    vTpmEnabled: securityType == 'TrustedLaunch' ? true : false
    tags: tags
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
    vmSize: vmSize
  }
  dependsOn: [
    imageDefinitionValidation
  ]
}

module customizeImage 'modules/customizeImage.bicep' = {
  name: '${depPrefix}Customize-Image-${timeStamp}'
  scope: resourceGroup(imageBuildRg.name)
  params: {
    cloud: cloud
    location: computeLocation
    containerName: containerName
    customizations: customizers
    installFsLogix: installFsLogix
    fslogixBlobName: fslogixBlobName
    installAccess:  installAccess
    installExcel: installExcel
    installOneDrive: installOneDrive
    onedriveBlobName: onedriveBlobName
    installOneNote: installOneNote
    installOutlook: installOutlook
    installPowerPoint: installPowerPoint
    installProject: installProject
    installPublisher: installpublisher
    installSkypeForBusiness: installSkypeForBusiness
    installTeams: installTeams
    installVirtualDesktopOptimizationTool: installVirtualDesktopOptimizationTool
    installVisio: installVisio
    installWord: installWord
    storageEndpoint: artifactsStorageAccount.properties.primaryEndpoints.blob
    userAssignedIdentityClientId: managedIdentity.properties.clientId
    managementVmName: managementVm.outputs.name
    imageVmName: imageVm.outputs.name
    vDotBlobName: vDotBlobName
    officeBlobName: officeBlobName
    teamsBlobName: teamsBlobName
    teamsVersion: teamsVersion
    logBlobContainerUri: collectLogs ? logContainerUri : ''
    installUpdates: installUpdates
    updateService: updateService
    wsusServer: wsusServer  
  }
}

module generalizeVm 'modules/generalizeVM.bicep' = {
  name: '${depPrefix}Generalize-VM-${timeStamp}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: computeLocation
    imageVmName: imageVm.outputs.name
    managementVmName: managementVm.outputs.name
    userAssignedIdentityClientId: managedIdentity.properties.clientId
  }
  dependsOn: [
    customizeImage
  ]
}

resource existingImageDefinition 'Microsoft.Compute/galleries/images@2022-03-03' existing = if (!empty(imageDefinitionResourceId)) {
  name: last(split(imageDefinitionResourceId, '/'))
  scope: resourceGroup(split(imageDefinitionResourceId, '/')[2], split(imageDefinitionResourceId, '/')[4])  
}

module imageDefinition '../../sharedModules/resources/compute/gallery/image/main.bicep' = if(empty(imageDefinitionResourceId)) {
  name: '${depPrefix}Gallery-Image-Definition-${timeStamp}'
  scope: resourceGroup(split(computeGalleryResourceId, '/')[2], split(computeGalleryResourceId, '/')[4])
  params: {
    location: deploymentLocation
    galleryName: last(split(computeGalleryResourceId,'/'))
    name: galleryImageDefinitionName
    hyperVGeneration: galleryImageDefinitionHyperVGeneration
    isHibernateSupported: imageDefinitionIsHibernateSupported
    isAcceleratedNetworkSupported: imageDefinitionIsAcceleratedNetworkSupported
    isHigherStoragePerformanceSupported: imageDefinitionIsHigherStoragePerformanceSupported
    securityType: galleryImageDefinitionSecurityType
    osType: 'Windows'
    osState: 'Generalized'
    publisher: galleryImageDefinitionPublisher
    offer: galleryImageDefinitionOffer
    sku: galleryImageDefinitionSku
  }
  dependsOn: [
    imageDefinitionValidation
  ]
}

// Image Definitions with Security Type = 'TrustedLaunchSupported', 'ConfidentialVMSupported', or TrustedLaunchConfidentialVMSupported' do not
// support capture directly from a VM. Must create a legacy managed image first.

module getImageSource '../../sharedModules/custom/customScriptExtension.bicep' = {
  name: '${depPrefix}Get-ImageVersion-Source-${timeStamp}'
  scope: resourceGroup(imageBuildRg.name)
  params: {
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Get-ImageVersionSource.ps1 ${getImageVersionSourceParameters}'
    fileUris: [
      '${artifactsContainerUri}Get-ImageVersionSource.ps1'
    ]
    output: true
    location: computeLocation
    userAssignedIdentityClientId: managedIdentity.properties.clientId
    virtualMachineName: managementVm.outputs.name
  }
  dependsOn: [
    generalizeVm
  ]
}

module imageVersion '../../sharedModules/resources/compute/gallery/image/version/main.bicep' = {
  name: '${depPrefix}ImageVersion-${timeStamp}'
  scope: resourceGroup(split(computeGalleryResourceId, '/')[2], split(computeGalleryResourceId, '/')[4])
  params: {
    location: deploymentLocation
    name: imageVersionName
    galleryName: last(split(computeGalleryResourceId, '/'))
    imageName: !empty(imageDefinitionResourceId) ? existingImageDefinition.name : imageDefinition.outputs.name
    endOfLifeDate: imageVersionEndOfLifeDate
    excludeFromLatest: imageVersionExcludeFromLatest
    replicaCount: imageVersionDefaultReplicaCount
    storageAccountType: imageVersionDefaultStorageAccountType
    sourceId: getImageSource.outputs.value.sourceId
    targetRegions: imageVersionReplicationRegions
    tags: {}
  }
}

module removeImageBuildResources 'modules/removeImageBuildResources.bicep' = {
  name: '${depPrefix}Remove-Build-Resources-${timeStamp}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: computeLocation
    imageResourceId: contains(getImageSource.outputs.value.sourceId, 'Microsoft.Compute/images') ? getImageSource.outputs.value.sourceId : ''
    imageVmName: imageVm.outputs.name
    managementVmName: managementVm.outputs.name
    userAssignedIdentityClientId: managedIdentity.properties.clientId
  }
  dependsOn: [
    imageVersion
  ]
}
