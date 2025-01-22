param artifactsUri string
param fileUris array
param location string
param scriptToRun string
param scriptArguments string
param userAssignedIdentityClientId string
param vmname string
param timeStamp string = utcNow('yyyyMMddhhmmss')

var baseUri = last(artifactsUri) == '/' ? artifactsUri : '${artifactsUri}/'
var cseUris = [for uri in fileUris: !contains(uri, '/') ? '${baseUri}${uri}' : uri]
var baseCommand = 'powershell -ExecutionPolicy Unrestricted -Command .\\${scriptToRun}'
var commandToExecute = !empty(scriptArguments) ? '${baseCommand} ${scriptArguments}' : baseCommand

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: vmname
}

resource CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: vm
  name: 'CustomScriptExtension'
  location: location
  tags: {}
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      timeStamp: timeStamp
    }
    protectedSettings: {
      commandToExecute: commandToExecute
      fileUris: cseUris
      managedIdentity: !empty(userAssignedIdentityClientId)
        ? {
            clientId: userAssignedIdentityClientId
          }
        : {}
    }
  }
}
