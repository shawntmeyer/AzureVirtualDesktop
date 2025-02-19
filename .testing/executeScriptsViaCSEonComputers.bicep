param artifactsUri string = 'https://ttimagemgmtassetsusgvasa.blob.core.usgovcloudapi.net/artifacts/'
param vmnames array = [
  'TT-Sensor-1'
  'TT-Sensor-2'
  'TT-Sensor-3'
  'TT-Sensor-4'
  'TT-Sensor-5'
  'TT-Sensor-6'
  'TT-Sensor-7'
  'TT-Sensor-8'
  'TT-Sensor-9'
  'TT-Sensor-10'
  'TT-Sensor-11'
  'TT-Sensor-12'
  'TT-Sensor-13'
]
param storageAccountResourceId string = '/subscriptions/49c206a0-7707-44f3-99ee-caa1f4124852/resourceGroups/TT-ImageManagement-SharedResources-rg/providers/Microsoft.Storage/storageAccounts/ttimagemgmtassetsusgvasa'
param CseBlobs array = [
  'cse_master_script.ps1'
  'MN14182NEPTUNECROSSINGWindowsVDI.zip'
]
param location string = 'USGovVirginia'
param timeStamp string = utcNow('yyyyMMddhhmmss')

var cseMasterScript = 'cse_master_script.ps1'
var cseUris = [for (blob, i) in CseBlobs: '${artifactsUri}${blob}']
var CSECommandToExecute = 'powershell -ExecutionPolicy Unrestricted -Command .\\${cseMasterScript}'
var storageAccountName = last(split(storageAccountResourceId, '/'))

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: storageAccountName
  scope: resourceGroup(split(storageAccountResourceId, '/')[2], split(storageAccountResourceId, '/')[4])
}
resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' existing = [for (vmname, i) in vmnames: {
  name: vmname
  scope: resourceGroup()
}]

resource CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for (vmname, i) in vmnames: {
  parent: vm[i]
  name: 'CustomScriptExtension'
  location: location
  tags: {}
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: cseUris
    }    
    protectedSettings: {
      commandToExecute: CSECommandToExecute
      storageAccountName: storageAccount.name
      storageAccountKey: storageAccount.listKeys().keys[0].value
    }
  }
}]
