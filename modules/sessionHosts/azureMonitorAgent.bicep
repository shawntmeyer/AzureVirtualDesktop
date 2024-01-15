param vmNames array
param location string = 'USGov Virginia'

resource windowsAgent 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = [for vmName in vmNames: {
  name: '${vmName}/AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}]
