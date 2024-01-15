param artifactsUri string
param files array
param executeScript string = ''
param location string
param output bool = false
param parameters string = ''
param tags object
param timeStamp string = utcNow('yyyyMMddhhmmss')
param userAssignedIdentityClientId string
param virtualMachineName string

var cseMasterScript = 'cse_master_script.ps1'
var ScriptToExecute = !empty(executeScript) ? executeScript : cseMasterScript
var CommandToExecute = empty(parameters) ? 'powershell -ExecutionPolicy Unrestricted -command .\\${ScriptToExecute}' : 'powershell -ExecutionPolicy Unrestricted -command .\\${ScriptToExecute} ${parameters}'
var FileNames = !empty(executeScript) ? union(['${executeScript}'], files) : union(['${cseMasterScript}'], files)
var FileUris = [for File in FileNames: '${artifactsUri}${File}']
var DefOutputValue =  {
  TimeStamp: timeStamp
  files: FileNames 
}

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
      timeStamp: timeStamp
      fileUris: FileUris
    }
    protectedSettings: contains(artifactsUri, environment().suffixes.storage) ? {
      commandToExecute: CommandToExecute
      managedIdentity: {
        clientId: userAssignedIdentityClientId
      }
    } : {
      commandToExecute: CommandToExecute
    }
  }
}

output value object = output ? json(filter(customScriptExtension.properties.instanceView.substatuses, item => item.code == 'ComponentStatus/StdOut/succeeded')[0].message) : json(string(DefOutputValue))
