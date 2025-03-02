targetScope = 'subscription'

param privateDnsZoneResourceIds array
param vnetId string
param timeStamp string

module privateDnsZoneVnetLinks './privateDnsZoneVnetLink.bicep' = [for (resId, i) in privateDnsZoneResourceIds: {
  name: 'privateDnsZoneVnetLink-${i}-${timeStamp}'
  scope: resourceGroup(split(resId, '/')[2], split(resId, '/')[4])
  params: {
    privateDnsZoneName: last(split(resId, '/'))
    vnetId: vnetId
  }
}]
