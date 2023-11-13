targetScope = 'subscription'

param ActiveDirectorySolution string
param ArtifactsLocation string
param AVDAgentInstallersBlobName string
param DiskEncryptionSolution string
param DiskSku string
param DomainName string
param CSEBlobNames array
param CSEMasterScript string
param FileShareNames object
param FslogixConfigureSessionHosts bool
param FslogixConfigurationBlobName string
param FslogixSolution string
param FslogixStorage string
param HostPoolType string
param ImageOffer string
param ImagePublisher string
param ImageSku string
param Locations object
param LocationVirtualMachines string
param ResourceGroupControlPlane string
param ResourceGroupHosts string
param ResourceGroupManagement string
param ResourceGroupStorage string
param SecurityPrincipals array
param SessionHostCount int
param SessionHostIndex int
param StorageCount int
param VirtualMachineNamePrefix string
param VirtualMachineSize string


//  BATCH SESSION HOSTS
// The following variables are used to determine the batches to deploy any number of AVD session hosts.
var MaxResourcesPerTemplateDeployment = 79 // This is the max number of session hosts that can be deployed from the sessionHosts.bicep file in each batch / for loop. Math: (800 - <Number of Static Resources>) / <Number of Looped Resources> 
var DivisionValue = SessionHostCount / MaxResourcesPerTemplateDeployment // This determines if any full batches are required.
var DivisionRemainderValue = SessionHostCount % MaxResourcesPerTemplateDeployment // This determines if any partial batches are required.
var SessionHostBatchCount = DivisionRemainderValue > 0 ? DivisionValue + 1 : DivisionValue // This determines the total number of batches needed, whether full and / or partial.

//  BATCH AVAILABILITY SETS
// The following variables are used to determine the number of availability sets.
var MaxAvSetMembers = 200 // This is the max number of session hosts that can be deployed in an availability set.
var BeginAvSetRange = SessionHostIndex / MaxAvSetMembers // This determines the availability set to start with.
var EndAvSetRange = (SessionHostCount + SessionHostIndex) / MaxAvSetMembers // This determines the availability set to end with.
var AvailabilitySetsCount = length(range(BeginAvSetRange, (EndAvSetRange - BeginAvSetRange) + 1))

// OTHER LOGIC & COMPUTED VALUES
var ArtifactsPath = last(ArtifactsLocation) == '/' ? ArtifactsLocation : '${ArtifactsLocation}/'
//  Ensure that the CSE Files are supplied correctly.
var Fslogix = FslogixStorage == 'None' ? false : true
var CSEArtifacts = FslogixConfigureSessionHosts ? union(['${CSEMasterScript}'], CSEBlobNames, ['${FslogixConfigurationBlobName}'], ['${AVDAgentInstallersBlobName}']) : union(['${CSEMasterScript}'], CSEBlobNames, ['${AVDAgentInstallersBlobName}'])
var CSEUris = [ for artifact in CSEArtifacts : contains(toLower(artifact), 'http') ? artifact : '${ArtifactsPath}${artifact}' ]
// Disk Encryption Options
var DiskEncryptionOptions = {
  AzureDiskEncryption: contains(DiskEncryptionSolution, 'ADE')
  EncryptionAtHost: contains(DiskEncryptionSolution, 'EAH')
  DiskEncryptionSet: contains(DiskEncryptionSolution, 'CMK')
  KeyEncryptionKey: contains(DiskEncryptionSolution, 'CMK') || contains(DiskEncryptionSolution, 'KEK')
}
var FileShares = FileShareNames[FslogixSolution]
// ONLY DEPLOY 1 storage account when Cloud Only identity is used because Sharding is not possible.
var CountStorage = ActiveDirectorySolution == 'AzureActiveDirectory' || ActiveDirectorySolution == 'AzureActiveDirectoryIntuneEnrollment' ? 1 : StorageCount
var Netbios = split(DomainName, '.')[0]
var PooledHostPool = split(HostPoolType, ' ')[0] == 'Pooled' ? true : false
var PrivateEndpoint = contains(FslogixStorage, 'PrivateEndpoint') ? true : false
var ResourceGroups = Fslogix ? [
  ResourceGroupControlPlane
  ResourceGroupHosts
  ResourceGroupManagement
  ResourceGroupStorage
] : [
  ResourceGroupControlPlane
  ResourceGroupHosts
  ResourceGroupManagement
]
var RoleDefinitions = {
  DesktopVirtualizationPowerOnContributor: '489581de-a3bd-480d-9518-53dea7416b33'
  DesktopVirtualizationUser: '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'
  Reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  VirtualMachineUserLogin: 'fb879df8-f326-4884-b1cf-06f3ad86be52'
}
var SecurityPrincipalsCount = length(SecurityPrincipals)
var SmbServerLocation = Locations[LocationVirtualMachines].abbreviation
var StorageSku = FslogixStorage == 'None' ? 'None' : split(FslogixStorage, ' ')[1]
var StorageSolution = split(FslogixStorage, ' ')[0]
var StorageSuffix = environment().suffixes.storage
var TimeDifference = Locations[LocationVirtualMachines].timeDifference
var TimeZone = Locations[LocationVirtualMachines].timeZone
var VmTemplate = '{"domain":"${DomainName}","galleryImageOffer":"${ImageOffer}","galleryImagePublisher":"${ImagePublisher}","galleryImageSKU":"${ImageSku}","imageType":"Gallery","imageUri":null,"customImageId":null,"namePrefix":"${VirtualMachineNamePrefix}","osDiskType":"${DiskSku}","useManagedDisks":true,"VirtualMachineSize":{"id":"${VirtualMachineSize}","cores":null,"ram":null},"galleryItemId":"${ImagePublisher}.${ImageOffer}${ImageSku}"}'

output ArtifactsLocation string = ArtifactsPath
output AvailabilitySetsCount int = AvailabilitySetsCount
output BeginAvSetRange int = BeginAvSetRange
output CSEUris array = CSEUris
output DiskEncryptionOptions object =  DiskEncryptionOptions
output DivisionRemainderValue int = DivisionRemainderValue
output FileShares array = FileShares
output Fslogix bool = Fslogix
output MaxResourcesPerTemplateDeployment int = MaxResourcesPerTemplateDeployment
output Netbios string = Netbios
output PooledHostPool bool = PooledHostPool
output PrivateEndpoint bool = PrivateEndpoint
output ResourceGroups array = ResourceGroups
output RoleDefinitions object = RoleDefinitions
output SessionHostBatchCount int = SessionHostBatchCount
output SecurityPrincipalsCount int = SecurityPrincipalsCount
output SmbServerLocation string = SmbServerLocation
output StorageSku string = StorageSku
output StorageSolution string = StorageSolution
output StorageSuffix string = StorageSuffix
output StorageCount int = CountStorage
output TimeDifference string = TimeDifference
output TimeZone string = TimeZone
output VmTemplate string = VmTemplate
