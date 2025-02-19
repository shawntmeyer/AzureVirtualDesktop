metadata name = 'Proximity Placement Groups'
metadata description = 'This module deploys a Proximity Placement Group.'
metadata owner = 'Azure/module-maintainers'

@description('Required. The name of the proximity placement group that is being created.')
param name string

@description('Optional. Specifies the type of the proximity placement group.')
@allowed([
  'Standard'
  'Ultra'
])
param type string = 'Standard'

@description('Optional. Resource location.')
param location string = resourceGroup().location

@description('Optional. Tags of the proximity placement group resource.')
param tags object = {}

@description('Optional. Specifies the Availability Zone where virtual machine, virtual machine scale set or availability set associated with the proximity placement group can be created.')
param zones array = []

@description('Optional. Describes colocation status of the Proximity Placement Group.')
param colocationStatus object = {}

@description('Optional. Specifies the user intent of the proximity placement group.')
param intent object = {}

resource proximityPlacementGroup 'Microsoft.Compute/proximityPlacementGroups@2022-08-01' = {
  name: name
  location: location
  tags: tags
  zones: zones
  properties: {
    proximityPlacementGroupType: type
    colocationStatus: colocationStatus
    intent: !empty(intent) ? intent : null
  }
}

@description('The name of the proximity placement group.')
output name string = proximityPlacementGroup.name

@description('The resourceId the proximity placement group.')
output resourceId string = proximityPlacementGroup.id

@description('The resource group the proximity placement group was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The location the resource was deployed into.')
output location string = proximityPlacementGroup.location
