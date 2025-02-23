@description('The name of the virtual machine to install the AVD Agent and register as a Session Host.')
param virtualMachineName string

@description('The location of the virtual machine to install the AVD Agent and register as a Session Host.')
param location string = resourceGroup().location

@description('The virtual machine is managed by Intune')
param intune bool = true

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-03-01' existing = {
  name: virtualMachineName
}

resource extension_AADLoginForWindows 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: intune ? {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    } : null
  }
}
