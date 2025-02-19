metadata name = 'Availability Sets'
metadata description = 'This module deploys an Availability Set.'
metadata owner = 'Azure/module-maintainers'

@description('Required. The name of the availability set that is being created.')
param name string

@description('Optional. The number of fault domains to use.')
param platformFaultDomainCount int = 2

@description('Optional. The number of update domains to use.')
param platformUpdateDomainCount int = 5

@description('Optional. SKU of the availability set.</p>- Use \'Aligned\' for virtual machines with managed disks.</p>- Use \'Classic\' for virtual machines with unmanaged disks.')
param skuName string = 'Aligned'

@description('Optional. Resource ID of a proximity placement group.')
param proximityPlacementGroupResourceId string = ''

@description('Optional. Resource location.')
param location string = resourceGroup().location

@description('Optional. Tags of the availability set resource.')
param tags object = {}

resource availabilitySet 'Microsoft.Compute/availabilitySets@2022-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    platformFaultDomainCount: platformFaultDomainCount
    platformUpdateDomainCount: platformUpdateDomainCount
    proximityPlacementGroup: !empty(proximityPlacementGroupResourceId) ? {
      id: proximityPlacementGroupResourceId
    } : null
  }
  sku: {
    name: skuName
  }
}

@description('The name of the availability set.')
output name string = availabilitySet.name

@description('The resource ID of the availability set.')
output resourceId string = availabilitySet.id

@description('The resource group the availability set was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The location the resource was deployed into.')
output location string = availabilitySet.location
