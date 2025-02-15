targetScope = 'subscription'

param computeGalleryResourceId string
param depPrefix string
param hyperVGeneration string
param imageBuildResourceGroupName string
param imageDefinitionSecurityType string
param imageName string
param imageVersionName string
param imageVersionDefaultReplicaCount int
param imageVersionDefaultStorageAccountType string
param imageVersionEOLinDays int
param imageVersionCreationTime string = utcNow()
param imageVersionExcludeFromLatest bool
param imageVersionReplicationRegions array
param location string
param remoteImageDefinitionResourceId string = ''
param remoteImageVersionDefaultReplicaCount int
param remoteImageVersionDefaultStorageAccountType string
param tags object
param timeStamp string
param virtualMachineResourceId string


var imageVersionEndOfLifeDate = imageVersionEOLinDays > 0 ? dateTimeAdd(imageVersionCreationTime, 'P${imageVersionEOLinDays}D') : ''

// Image Definitions with Security Type = 'TrustedLaunchSupported', 'ConfidentialVMSupported', or TrustedLaunchConfidentialVMSupported' do not
// support capture directly from a VM. Must create a legacy managed image first.

module managedImage '../../../sharedModules/resources/compute/image/main.bicep' = if(contains(imageDefinitionSecurityType, 'Supported')) {
  name: '${depPrefix}Image-${timeStamp}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    hyperVGeneration: hyperVGeneration
    location: location
    name: 'img-${last(split(virtualMachineResourceId, '/'))}'
    sourceVirtualMachineResourceId: virtualMachineResourceId
    tags: tags[?'Microsoft.Compute/images'] ?? {}
  }
}

module imageVersion '../../../sharedModules/resources/compute/gallery/image/version/main.bicep' = {
  name: '${depPrefix}ImageVersion-${timeStamp}'
  scope: resourceGroup(split(computeGalleryResourceId, '/')[2], split(computeGalleryResourceId, '/')[4])
  params: {
    location: location
    name: imageVersionName
    galleryName: last(split(computeGalleryResourceId, '/'))
    imageName: imageName
    endOfLifeDate: imageVersionEndOfLifeDate
    excludeFromLatest: imageVersionExcludeFromLatest
    replicaCount: imageVersionDefaultReplicaCount
    storageAccountType: imageVersionDefaultStorageAccountType
    sourceId: contains(imageDefinitionSecurityType, 'Supported') ? managedImage.outputs.resourceId : virtualMachineResourceId
    targetRegions: imageVersionReplicationRegions
    tags: tags[?'Microsoft.Compute/galleries/images/versions'] ?? {}
  }
}

resource remoteImageDefinition 'Microsoft.Compute/galleries/images@2024-03-03' existing = if(!empty(remoteImageDefinitionResourceId)) {
  name: last(split(remoteImageDefinitionResourceId, '/'))
  scope: resourceGroup(split(remoteImageDefinitionResourceId, '/')[2], split(remoteImageDefinitionResourceId, '/')[4])
}

module remoteImageVersion '../../../sharedModules/resources/compute/gallery/image/version/main.bicep' = if(!empty(remoteImageDefinitionResourceId)) {
  name: '${depPrefix}RemoteImageVersion-${timeStamp}'
  scope: resourceGroup(split(remoteImageDefinitionResourceId, '/')[2], split(remoteImageDefinitionResourceId, '/')[4])
  params: {
    location: !empty(remoteImageDefinitionResourceId) ? remoteImageDefinition.location : location
    name: imageVersionName
    galleryName: last(split(remoteImageDefinitionResourceId, '/'))
    imageName: remoteImageDefinition.name
    endOfLifeDate: imageVersionEndOfLifeDate
    excludeFromLatest: imageVersionExcludeFromLatest
    replicaCount: remoteImageVersionDefaultReplicaCount
    storageAccountType: remoteImageVersionDefaultStorageAccountType
    sourceId: imageVersion.outputs.resourceId
    tags: tags[?'Microsoft.Compute/galleries/images/versions'] ?? {}
  }
}

output managedImageId string = contains(imageDefinitionSecurityType, 'Supported') ? managedImage.outputs.resourceId : ''
output imageVersionId string = imageVersion.outputs.resourceId
