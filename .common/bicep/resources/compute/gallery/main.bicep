metadata name = 'Azure Compute Galleries'
metadata description = 'This module deploys an Azure Compute Gallery (formerly known as Shared Image Gallery).'
metadata owner = 'Azure/module-maintainers'

@minLength(1)
@sys.description('Required. Name of the Azure Compute Gallery.')
param name string

@sys.description('Optional. Location for all resources.')
param location string = resourceGroup().location

@sys.description('Optional. Description of the Azure Shared Image Gallery.')
param description string = ''

@sys.description('Optional. Applications to create.')
param applications array = []

@sys.description('Optional. Images to create.')
param images array = []

@sys.description('Optional. Tags for all resources.')
param tags object = {}

resource gallery 'Microsoft.Compute/galleries@2022-03-03' = {
  name: name
  location: location
  tags: tags
  properties: {
    description: description
    identifier: {}
  }
}

// Applications
module galleries_applications 'application/main.bicep' = [for (application, index) in applications: {
  name: '${uniqueString(deployment().name, location)}-Gallery-Application-${index}'
  params: {
    location: location
    name: application.name
    galleryName: gallery.name
    supportedOSType: contains(application, 'supportOSType') ? application.supportedOSType : 'Windows'
    description: contains(application, 'description') ? application.description : ''
    eula: contains(application, 'eula') ? application.eula : ''
    privacyStatementUri: contains(application, 'privacyStatementUri') ? application.privacyStatementUri : ''
    releaseNoteUri: contains(application, 'releaseNoteUri') ? application.releaseNoteUri : ''
    endOfLifeDate: contains(application, 'endOfLifeDate') ? application.endOfLifeDate : ''
    customActions: contains(application, 'customActions') ? application.customActions : []
    tags: contains(application, 'tags') ? application.tags : {}
  }
}]

// Images
module galleries_images 'image/main.bicep' = [for (image, index) in images: {
  name: '${uniqueString(deployment().name, location)}-Gallery-Image-${index}'
  params: {
    location: location
    name: image.name
    galleryName: gallery.name
    osType: contains(image, 'osType') ? image.osType : 'Windows'
    osState: contains(image, 'osState') ? image.osState : 'Generalized'
    publisher: contains(image, 'publisher') ? image.publisher : 'MicrosoftWindowsServer'
    offer: contains(image, 'offer') ? image.offer : 'WindowsServer'
    sku: contains(image, 'sku') ? image.sku : '2019-Datacenter'
    minRecommendedvCPUs: contains(image, 'minRecommendedvCPUs') ? image.minRecommendedvCPUs : 1
    maxRecommendedvCPUs: contains(image, 'maxRecommendedvCPUs') ? image.maxRecommendedvCPUs : 4
    minRecommendedMemory: contains(image, 'minRecommendedMemory') ? image.minRecommendedMemory : 4
    maxRecommendedMemory: contains(image, 'maxRecommendedMemory') ? image.maxRecommendedMemory : 16
    hyperVGeneration: contains(image, 'hyperVGeneration') ? image.hyperVGeneration : 'V1'
    securityType: contains(image, 'securityType') ? image.securityType : 'Standard'
    description: contains(image, 'description') ? image.description : ''
    eula: contains(image, 'eula') ? image.eula : ''
    privacyStatementUri: contains(image, 'privacyStatementUri') ? image.privacyStatementUri : ''
    releaseNoteUri: contains(image, 'releaseNoteUri') ? image.releaseNoteUri : ''
    productName: contains(image, 'productName') ? image.productName : ''
    planName: contains(image, 'planName') ? image.planName : ''
    planPublisherName: contains(image, 'planPublisherName') ? image.planPublisherName : ''
    endOfLife: contains(image, 'endOfLife') ? image.endOfLife : ''
    excludedDiskTypes: contains(image, 'excludedDiskTypes') ? image.excludedDiskTypes : []
    tags: contains(image, 'tags') ? image.tags : {}
  }
}]

@sys.description('The resource ID of the deployed image gallery.')
output resourceId string = gallery.id

@sys.description('The resource group of the deployed image gallery.')
output resourceGroupName string = resourceGroup().name

@sys.description('The name of the deployed image gallery.')
output name string = gallery.name

@sys.description('The location the resource was deployed into.')
output location string = gallery.location
