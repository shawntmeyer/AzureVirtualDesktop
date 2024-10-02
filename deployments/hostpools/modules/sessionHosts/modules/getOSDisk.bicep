param diskAccessId string
param diskName string
param location string
param timeStamp string
param vmName string

resource getDisk 'Microsoft.Compute/disks@2023-10-02' existing = {
  name: diskName
}

module updateDisk 'updateOSDisk.bicep' = {
  name: 'Update_OSDisk_${vmName}_Stage2_${timeStamp}'
  params: {
    diskName: diskName
    creationData: getDisk.properties.creationData
    diskAccessId: diskAccessId
    location: location
  }
}

