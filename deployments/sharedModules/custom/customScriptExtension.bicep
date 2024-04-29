param artifactsLocation string
param files array
param powerShellScriptName string = ''
param location string
param scriptParameters string = ''
param tags object = {}
param timeStamp string = utcNow('yyyyMMddhhmmss')
param userAssignedIdentityClientId string
param virtualMachineName string

var commandToExecute = empty(scriptParameters) ? 'powershell -ExecutionPolicy Unrestricted -command .\\${powerShellScriptName}' : 'powershell -ExecutionPolicy Unrestricted -command .\\${powerShellScriptName} ${scriptParameters}'
var fileNames = !empty(powerShellScriptName) ? union(['${powerShellScriptName}}'], files) : files
var fileUris = [for file in fileNames: '${artifactsLocation}${file}']

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name: virtualMachineName
}

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: virtualMachine
  name: 'CustomScriptExtension'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      timestamp: timeStamp
      fileUris: fileUris
    }
    protectedSettings: contains(artifactsLocation, environment().suffixes.storage) ? {
      commandToExecute: commandToExecute
      managedIdentity: {
        clientId: userAssignedIdentityClientId
      }
    } : {
      commandToExecute: commandToExecute
    }
  }
}

output value object = json(filter(customScriptExtension.properties.instanceView.substatuses, item => item.code == 'ComponentStatus/StdOut/succeeded')[0].message)
