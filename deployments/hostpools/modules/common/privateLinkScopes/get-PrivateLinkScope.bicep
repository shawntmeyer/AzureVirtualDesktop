targetScope = 'subscription'

param privateLinkScopeResourceId string
param scopedResourceIds array
param timeStamp string

module addScopedResources 'addScopedResources-PrivateLinkScope.bicep' = {
  scope: resourceGroup(split(privateLinkScopeResourceId, '/')[2], split(privateLinkScopeResourceId, '/')[4])
  name: 'addScopedResources-${timeStamp}'
  params: {
    privateLinkScopeResourceId: privateLinkScopeResourceId
    scopedResourceIds: scopedResourceIds
  }
}
