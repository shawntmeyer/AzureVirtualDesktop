param azModuleBlobName string
param identitySolution string
param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param confidentialVMOSDiskEncryptionType string
param diskEncryptionSetResourceId string
param diskNamePrefix string
param diskSku string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param encryptionAtHost bool
param location string
param networkInterfaceNamePrefix string
param securityType string
param subnetResourceId string
param tagsNetworkInterfaces object
param tagsVirtualMachines object
param timeStamp string = utcNow('yyyyMMddhhmmss')
param userAssignedIdentitiesResourceIds object
param virtualMachineNamePrefix string
@secure()
param virtualMachineAdminPassword string
param virtualMachineAdminUserName string

var NicName = '${networkInterfaceNamePrefix}mgt'
var VmName = '${virtualMachineNamePrefix}mgt'

resource networkInterface 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: NicName
  location: location
  tags: tagsNetworkInterfaces
  properties: {
    ipConfigurations: [
      {
        name: 'Ipv4config'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetResourceId
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
        name: '${diskNamePrefix}mgt'
        osType: 'Windows'
        createOption: 'FromImage'
        deleteOption: 'Delete'
        caching: 'None'
        managedDisk: {
          diskEncryptionSet: securityType != 'ConfidentialVM' && !empty(diskEncryptionSetResourceId) ? {
            id: diskEncryptionSetResourceId
          } : null
          securityProfile: securityType == 'ConfidentialVM' ? {
            diskEncryptionSet: !empty(diskEncryptionSetResourceId) ? {
              id: diskEncryptionSetResourceId
            } : null
            securityEncryptionType: confidentialVMOSDiskEncryptionType
          } : null
          storageAccountType: diskSku
        }
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
    userAssignedIdentities: userAssignedIdentitiesResourceIds
  }
}

resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = if(contains(identitySolution, 'DomainServices')) {
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

resource extension_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: virtualMachine
  name: 'CustomScriptExtension'
  location: location
  tags: tagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      timeStamp: timeStamp
    }    
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File cse_master_script.ps1'
      fileUris: [
        '${artifactsUri}${azModuleBlobName}'
        '${artifactsUri}cse_master_script.ps1'
      ]
      managedIdentity: { clientId: artifactsUserAssignedIdentityClientId }
    }
  }
}

output Name string = virtualMachine.name
