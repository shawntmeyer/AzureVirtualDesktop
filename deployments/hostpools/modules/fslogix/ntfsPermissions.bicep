param artifactsUri string
@secure()
param commandToExecute string
param location string
param managementVirtualMachineName string
param tagsVirtualMachines object
param timeStamp string
param userAssignedIdentityClientId string

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: '${managementVirtualMachineName}/CustomScriptExtension'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${artifactsUri}Set-NtfsPermissions.ps1'
      ]
      timeStamp: timeStamp
    }
    protectedSettings: !empty(userAssignedIdentityClientId) ? {
      managedIdentity: {
        clientId: userAssignedIdentityClientId
      }
      commandToExecute: commandToExecute
    } : {
      commandToExecute: commandToExecute
    }
  }
}
