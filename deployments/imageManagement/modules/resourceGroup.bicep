targetScope = 'subscription'

param ResourceGroupName string
param Location string = deployment().location

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: ResourceGroupName
  location: Location
}

output resourceId string = resourceGroup.id
output name string = resourceGroup.name
output location string = resourceGroup.location
