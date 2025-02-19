param fileUris array
param location string
param scriptToRun string
param scriptArguments string
param userAssignedIdentityResourceId string
param vmName string

var baseCommand = 'powershell -ExecutionPolicy Unrestricted -Command .\\${scriptToRun}'
var commandToExecute = !empty(scriptArguments) ? '${baseCommand} ${scriptArguments}' : baseCommand

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if(!empty(userAssignedIdentityResourceId)) {
  name: last(split(userAssignedIdentityResourceId, '/'))
  scope: resourceGroup(split(userAssignedIdentityResourceId, '/')[2], split(userAssignedIdentityResourceId, '/')[4])
}

resource CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  name: '${vmName}/AzurePolicyforWindows'
  location: location
  tags: {}
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: commandToExecute
      fileUris: fileUris
      managedIdentity: !empty(userAssignedIdentityResourceId)
        ? {
            clientId: userAssignedIdentity.properties.clientId
          }
        : {}
    }
    settings: {}
  }
}
