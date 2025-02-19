param dnsZoneResourceId string
param ipv4Address string
param recordName string
param timeStamp string

module aRecord 'aRecord.bicep' = {
  name: 'scmARecord-${timeStamp}'
  scope: resourceGroup(split(dnsZoneResourceId, '/')[2], split(dnsZoneResourceId, '/')[4])
  params: {
    recordName: recordName
    ipv4Address: ipv4Address
    privateDnsZoneName: last(split(dnsZoneResourceId, '/'))
  }
}
