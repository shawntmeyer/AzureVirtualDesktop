targetScope = 'subscription'
param imageDefinitionResourceId string = '/subscriptions/70c1bb3a-115f-4300-becd-5f74200999bb/resourceGroups/rg-avd-image-management-va/providers/Microsoft.Compute/galleries/gal_avd_image_management_va/images/vmid-MicrosoftWindowsDesktop-office365-win1124h2avd'
param remoteComputeGalleryResourceId string = '/subscriptions/70c1bb3a-115f-4300-becd-5f74200999bb/resourceGroups/RG-AVD-IMAGE-MANAGEMENT-TX/providers/Microsoft.Compute/galleries/gal_avd_tx'
param galleryImageDefinitionName string = ''
param imageDefinitionPublisher string = ''
param imageDefinitionOffer string = ''
param imageDefinitionSku string = ''
param imageDefinitionIsHibernateSupported bool = false
param imageDefinitionIsHigherStoragePerformanceSupported bool = false
param imageDefinitionIsAcceleratedNetworkSupported bool = false
param imageDefinitionSecurityType string = 'TrustedLaunch'
param publisher string = ''
param offer string = ''
param sku string = ''
param tags object = {}

var imageDefinitionFeatures = !empty(imageDefinitionResourceId)
  ? existingImageDefinition.properties.features
  : [
      {
        name: 'IsHibernateSupported'
        value: imageDefinitionIsHibernateSupported
      }
      {
        name: 'DiskControllerTypes'
        value: imageDefinitionIsHigherStoragePerformanceSupported
      }
      {
        name: 'IsAcceleratedNetworkSupported'
        value: imageDefinitionIsAcceleratedNetworkSupported
      }
      {
        name: 'SecurityType'
        value: imageDefinitionSecurityType
      }
    ]
var galleryImageDefinitionHyperVGeneration = endsWith(sku, 'g2') || startsWith(sku, 'win11') ? 'V2' : 'V1'
var galleryImageDefinitionPublisher = !empty(imageDefinitionPublisher)
  ? replace(imageDefinitionPublisher, ' ', '')
  : publisher

var galleryImageDefinitionSku = !empty(imageDefinitionSku) ? replace(imageDefinitionSku, ' ', '') : sku
var galleryImageDefinitionOffer = !empty(imageDefinitionOffer) ? replace(imageDefinitionOffer, ' ', '') : offer

var remoteLocation = !empty(remoteComputeGalleryResourceId) ? remoteComputeGallery.location : ''

resource existingImageDefinition 'Microsoft.Compute/galleries/images@2023-07-03' existing = if (!empty(imageDefinitionResourceId)) {
  name: '${split(imageDefinitionResourceId, '/')[8]}/${last(split(imageDefinitionResourceId, '/'))}'
  scope: resourceGroup(split(imageDefinitionResourceId, '/')[2], split(imageDefinitionResourceId, '/')[4])
}

resource remoteComputeGallery 'Microsoft.Compute/galleries@2024-03-03' existing = if (!empty(remoteComputeGalleryResourceId)) {
  name: last(split(remoteComputeGalleryResourceId, '/'))
  scope: resourceGroup(split(remoteComputeGalleryResourceId, '/')[2], split(remoteComputeGalleryResourceId, '/')[4])
}

output remoteGalleryResourceGroup string = split(remoteComputeGalleryResourceId, '/')[4]
output remoteGallerySubscription string = split(remoteComputeGalleryResourceId, '/')[2]
output galleryName string = last(split(remoteComputeGalleryResourceId, '/'))
output remoteGalleryLocation string = remoteLocation
output imageDefinitionName string = empty(imageDefinitionResourceId)
  ? galleryImageDefinitionName
  : last(split(imageDefinitionResourceId, '/'))
output imageDefinitionSubscription string = split(imageDefinitionResourceId, '/')[2]
output imageDefinitionResourceGroup string = split(imageDefinitionResourceId, '/')[4]

output existingLocation string = existingImageDefinition.location

output hyperVGeneration string = empty(imageDefinitionResourceId)
  ? galleryImageDefinitionHyperVGeneration
  : existingImageDefinition.properties.hyperVGeneration

output isHibernateSupported bool = !empty(filter(imageDefinitionFeatures, feature => feature.name == 'IsHibernateSupported'))
      ? bool(filter(imageDefinitionFeatures, feature => feature.name == 'IsHibernateSupported')[0].value)
      : false
output isAcceleratedNetworkSupported bool = !empty(filter(imageDefinitionFeatures, feature => feature.name == 'IsAcceleratedNetworkSupported'))
      ? bool(filter(imageDefinitionFeatures, feature => feature.name == 'IsAcceleratedNetworkSupported')[0].value)
      : false
output isHigherStoragePerformanceSupported bool = !empty(filter(imageDefinitionFeatures, feature => feature.name == 'DiskControllerTypes'))
      ? bool(filter(imageDefinitionFeatures, feature => feature.name == 'DiskControllerTypes')[0].value)
      : false

output securityType string = !empty(filter(imageDefinitionFeatures, feature => feature.name == 'SecurityType'))
      ? any(filter(imageDefinitionFeatures, feature => feature.name == 'SecurityType')[0].value)
      : 'Standard'

output publisher string = empty(imageDefinitionResourceId)
  ? galleryImageDefinitionPublisher
  : existingImageDefinition.properties.identifier.publisher
output offer string = empty(imageDefinitionResourceId)
  ? galleryImageDefinitionOffer
  : existingImageDefinition.properties.identifier.offer
output sku string = empty(imageDefinitionResourceId)
  ? galleryImageDefinitionSku
  : existingImageDefinition.properties.identifier.sku
output tags object = tags[?'Microsoft.Compute/galleries/images'] ?? {}
