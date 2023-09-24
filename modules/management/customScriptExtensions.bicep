param ArtifactsLocation string
param Files array
param ExecuteScript string = ''
param Location string
param Output bool = false
param Parameters string = ''
param Tags object
param Timestamp string = utcNow('yyyyMMddhhmmss')
param UserAssignedIdentityClientId string
param VirtualMachineName string


var CSEMasterScript = 'cse_master_script.ps1'
var ScriptToExecute = !empty(ExecuteScript) ? ExecuteScript : CSEMasterScript
var CommandToExecute = empty(Parameters) ? 'powershell -ExecutionPolicy Unrestricted -command .\\${ScriptToExecute}' : 'powershell -ExecutionPolicy Unrestricted -command .\\${ScriptToExecute} ${Parameters}'
var FileNames = !empty(ExecuteScript) ? union(['${ExecuteScript}'], Files) : union(['${CSEMasterScript}'], Files)
var FileUris = [for File in FileNames: '${ArtifactsLocation}${File}']
var DefOutputValue =  {
  TimeStamp: Timestamp
  Files: FileNames 
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name: VirtualMachineName
}

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: virtualMachine
  name: 'CustomScriptExtension'
  location: Location
  tags: Tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      timestamp: Timestamp
      fileUris: FileUris
    }
    protectedSettings: contains(ArtifactsLocation, environment().suffixes.storage) ? {
      commandToExecute: CommandToExecute
      managedIdentity: {
        clientId: UserAssignedIdentityClientId
      }
    } : {
      commandToExecute: CommandToExecute
    }
  }
}

output value object = Output ? json(filter(customScriptExtension.properties.instanceView.substatuses, item => item.code == 'ComponentStatus/StdOut/succeeded')[0].message) : json(string(DefOutputValue))
