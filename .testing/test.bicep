param roleDefinitionId string = '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'
param applicationGroupResourceId string = '/subscriptions/70c1bb3a-115f-4300-becd-5f74200999bb/resourcegroups/rg-avd-control-plane-va/providers/Microsoft.DesktopVirtualization/applicationgroups/vddag-il5-test1-va'
param principalId string = '49f5ec78-599a-4fa8-b9b6-63ca3018ebd1'

output subscriptionResourceId string = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
output guid string = guid(applicationGroupResourceId, principalId, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId))
