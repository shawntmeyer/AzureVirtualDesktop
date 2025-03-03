param hostPoolType string
param loadBalancerType string
param location string
param name string
param preferredAppGroupType string
param time string = utcNow()

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' = {
  location: location
  name: name
  properties: {
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    preferredAppGroupType: preferredAppGroupType
    registrationInfo: {
      expirationTime: dateTimeAdd(time, 'PT2H')
      registrationTokenOperation: 'Update'
    }
  }
}
