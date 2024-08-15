param disks_disk_demo6usw_name string = 'disk-demo6usw'
param diskAccesses_da_test_usw_externalid string = '/subscriptions/6dc4ed51-16b9-4494-a406-4fb7a8330d95/resourceGroups/RG-TEMPLATESPECS/providers/Microsoft.Compute/diskAccesses/da-test-usw'

resource disks_disk_demo6usw_name_resource 'Microsoft.Compute/disks@2023-10-02' = {
  name: disks_disk_demo6usw_name
  location: 'westus'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    osType: 'Windows'
    hyperVGeneration: 'V2'
    supportsHibernation: true
    supportedCapabilities: {
      diskControllerTypes: 'SCSI, NVMe'
      acceleratedNetwork: true
      architecture: 'x64'
    }
    creationData: {
      createOption: 'FromImage'
      imageReference: {
        id: '/Subscriptions/6dc4ed51-16b9-4494-a406-4fb7a8330d95/Providers/Microsoft.Compute/Locations/westus/Publishers/MicrosoftWindowsServer/ArtifactTypes/VMImage/Offers/WindowsServer/Skus/2019-datacenter-core-g2/Versions/17763.6054.240703'
      }
    }
    diskSizeGB: 127
    diskIOPSReadWrite: 500
    diskMBpsReadWrite: 100
    encryption: {
      type: 'EncryptionAtRestWithPlatformKey'
    }
    diskAccessId: diskAccesses_da_test_usw_externalid
    networkAccessPolicy: 'AllowPrivate'
    securityProfile: {
      securityType: 'TrustedLaunch'
    }
    publicNetworkAccess: 'Disabled'
    tier: 'P10'
  }
}
