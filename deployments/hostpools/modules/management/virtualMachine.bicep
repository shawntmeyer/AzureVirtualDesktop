param activeDirectorySolution string
param artifactsUri string
param diskEncryptionOptions object
param diskEncryptionSetResourceId string
param diskNamePrefix string
param diskSku string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param location string
param networkInterfaceNamePrefix string
param subnet string
param tagsNetworkInterfaces object
param tagsVirtualMachines object
param timeStamp string = utcNow('yyyyMMddhhmmss')
param userAssignedIdentityClientId string
param UserAssignedIdentityResourceIds object
param virtualNetwork string
param virtualNetworkResourceGroup string
param virtualMachineNamePrefix string
@secure()
param virtualMachineAdminPassword string
param virtualMachineAdminUserName string

var diskEncryptionSet = bool(diskEncryptionOptions.diskEncryptionSet)
var encryptionAtHost = bool(diskEncryptionOptions.encryptionAtHost)

var NicName = '${networkInterfaceNamePrefix}mgt'
var VmName = '${virtualMachineNamePrefix}mgt'

resource networkInterface 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: NicName
  location: location
  tags: tagsNetworkInterfaces
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork, subnet)
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: VmName
  location: location
  tags: tagsVirtualMachines
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-core-g2'
        version: 'latest'
      }
      osDisk: {
        deleteOption: 'Delete'
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'None'
        managedDisk: {
          diskEncryptionSet: diskEncryptionSet ? {
            id: diskEncryptionSetResourceId
          } : null
          storageAccountType: diskSku
        }
        name: '${diskNamePrefix}mgt'
      }
      dataDisks: []
    }
    osProfile: {
      computerName: VmName
      adminUsername: virtualMachineAdminUserName
      adminPassword: virtualMachineAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'trustedLaunch'
      encryptionAtHost: encryptionAtHost
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    licenseType: 'Windows_Server'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: UserAssignedIdentityResourceIds
  }
}

resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = if(contains(activeDirectorySolution, 'DomainServices')) {
  parent: virtualMachine
  name: 'JsonADDomainExtension'
  location: location
  tags: tagsVirtualMachines
  properties: {
    forceUpdateTag: timeStamp
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: domainName
      User: domainJoinUserPrincipalName
      Restart: 'true'
      Options: '3'
    }
    protectedSettings: {
      Password: domainJoinUserPassword
    }
  }
}

module extension_CustomScriptExtension 'customScriptExtensions.bicep' = {
  name: 'CSE_InstallAzurePowerShellAzModule_${timeStamp}'
  params: {
    artifactsUri: artifactsUri
    executeScript: ''
    files: ['PowerShell-Az-Module.zip']
    location: location
    parameters: ''
    tags: tagsVirtualMachines
    virtualMachineName: virtualMachine.name
    userAssignedIdentityClientId: userAssignedIdentityClientId
  }
}

output Name string = virtualMachine.name
