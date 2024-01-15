metadata name = 'Route Tables'
metadata description = 'This module deploys a User Defined Route Table (UDR).'
metadata owner = 'Azure/module-maintainers'

@description('Required. Name given for the hub route table.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. An Array of Routes to be established within the hub route table.')
param routes array = []

@description('Optional. Switch to disable BGP route propagation.')
param disableBgpRoutePropagation bool = false

@description('Optional. Tags of the resource.')
param tags object = {}

resource routeTable 'Microsoft.Network/routeTables@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    routes: routes
    disableBgpRoutePropagation: disableBgpRoutePropagation
  }
}

@description('The resource group the route table was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name of the route table.')
output name string = routeTable.name

@description('The resource ID of the route table.')
output resourceId string = routeTable.id

@description('The location the resource was deployed into.')
output location string = routeTable.location
