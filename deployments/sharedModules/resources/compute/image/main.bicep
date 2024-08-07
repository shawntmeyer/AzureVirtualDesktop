metadata name = 'Images'
metadata description = 'This module deploys a Compute Image.'
metadata owner = 'Azure/module-maintainers'

@description('Required. The name of the image.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. The Virtual Hard Disk.')
param osDiskBlobUri string = ''

@description('Optional. This property allows you to specify the type of the OS that is included in the disk if creating a VM from a custom image. - Windows or Linux.')
param osType string = ''

@description('Optional. Specifies the caching requirements. Default: None for Standard storage. ReadOnly for Premium storage. - None, ReadOnly, ReadWrite.')
param osDiskCaching string = ''

@description('Optional. Specifies the storage account type for the managed disk. NOTE: UltraSSD_LRS can only be used with data disks, it cannot be used with OS Disk. - Standard_LRS, Premium_LRS, StandardSSD_LRS, UltraSSD_LRS.')
param osAccountType string = ''

@description('Optional. Default is false. Specifies whether an image is zone resilient or not. Zone resilient images can be created only in regions that provide Zone Redundant Storage (ZRS).')
param zoneResilient bool = false

@description('Optional. Gets the HyperVGenerationType of the VirtualMachine created from the image. - V1 or V2.')
param hyperVGeneration string = 'V2'

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. The extended location of the Image.')
param extendedLocation object = {}

@description('Optional. The source virtual machine from which Image is created.')
param sourceVirtualMachineResourceId string = ''

@description('Optional. Specifies the customer managed disk encryption set resource ID for the managed image disk.')
param diskEncryptionSetResourceId string = ''

@description('Optional. The managedDisk.')
param managedDiskResourceId string = ''

@description('Optional. Specifies the size of empty data disks in gigabytes. This element can be used to overwrite the name of the disk in a virtual machine image. This value cannot be larger than 1023 GB.')
param diskSizeGB int = 128

@description('Optional. The OS State. For managed images, use Generalized.')
@allowed([
  'Generalized'
  'Specialized'
])
param osState string = 'Generalized'

@description('Optional. The snapshot resource ID.')
param snapshotResourceId string = ''

@description('Optional. Specifies the parameters that are used to add a data disk to a virtual machine.')
param dataDisks array = []

resource image 'Microsoft.Compute/images@2023-03-01' = {
  name: name
  location: location
  tags: tags
  extendedLocation: !empty(extendedLocation) ? extendedLocation : null
  properties: {
    storageProfile: {
      osDisk: empty(sourceVirtualMachineResourceId) ? {
        osType: osType
        blobUri: !empty(osDiskBlobUri) ? osDiskBlobUri : null
        caching: !empty(osDiskCaching) ? osDiskCaching : null
        storageAccountType: osAccountType
        osState: osState
        diskEncryptionSet: !empty(diskEncryptionSetResourceId) ? {
          id: diskEncryptionSetResourceId
        } : null
        diskSizeGB: diskSizeGB
        managedDisk: !empty(managedDiskResourceId) ? {
          id: managedDiskResourceId
        } : null
        snapshot: !empty(snapshotResourceId) ? {
          id: snapshotResourceId
        } : null
      } : null
      dataDisks: empty(dataDisks) ? null : dataDisks
      zoneResilient: zoneResilient
    }
    hyperVGeneration: hyperVGeneration
    sourceVirtualMachine: !empty(sourceVirtualMachineResourceId) ? {
      id: sourceVirtualMachineResourceId
    } : null
  }
}

@description('The resource ID of the image.')
output resourceId string = image.id

@description('The resource group the image was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name of the image.')
output name string = image.name

@description('The location the resource was deployed into.')
output location string = image.location
