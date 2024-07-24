@secure()
param extensions_CustomScriptExtension_commandToExecute string

@secure()
param extensions_IaaSAntimalware_Paths string

@secure()
param extensions_IaaSAntimalware_Extensions string

@secure()
param extensions_IaaSAntimalware_Processes string
param virtualMachines_demo6usw_name string = 'demo6usw'
param disks_disk_demo6usw_externalid string = '/subscriptions/6dc4ed51-16b9-4494-a406-4fb7a8330d95/resourceGroups/rg-avd-demo6-management-usw/providers/Microsoft.Compute/disks/disk-demo6usw'
param networkInterfaces_nic_demo6usw_externalid string = '/subscriptions/6dc4ed51-16b9-4494-a406-4fb7a8330d95/resourceGroups/rg-avd-demo6-management-usw/providers/Microsoft.Network/networkInterfaces/nic-demo6usw'

resource virtualMachines_demo6usw_name_resource 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: virtualMachines_demo6usw_name
  location: 'westus'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/6dc4ed51-16b9-4494-a406-4fb7a8330d95/resourceGroups/rg-avd-image-management-use/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-image-management-use': {}
      '/subscriptions/6dc4ed51-16b9-4494-a406-4fb7a8330d95/resourceGroups/rg-avd-demo6-management-usw/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-demo6-avd-deployment-usw': {}
    }
  }
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
        osType: 'Windows'
        name: 'disk-${virtualMachines_demo6usw_name}'
        createOption: 'FromImage'
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
          id: disks_disk_demo6usw_externalid
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
      dataDisks: []
      diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: virtualMachines_demo6usw_name
      adminUsername: 'vmadmin'
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
      secrets: []
      allowExtensionOperations: true
      requireGuestProvisionSignal: true
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      encryptionAtHost: true
      securityType: 'TrustedLaunch'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces_nic_demo6usw_externalid
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    licenseType: 'Windows_Server'
  }
}

resource virtualMachines_demo6usw_name_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: virtualMachines_demo6usw_name_resource
  name: 'CustomScriptExtension'
  location: 'westus'
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    settings: {
      fileUris: [
        'https://saimageassetsusexj5oy5dp.blob.core.windows.net/artifacts/Get-Validations.ps1'
      ]
      commandToExecute: extensions_CustomScriptExtension_commandToExecute
    }
    protectedSettings: {}
  }
}

resource virtualMachines_demo6usw_name_IaaSAntimalware 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: virtualMachines_demo6usw_name_resource
  name: 'IaaSAntimalware'
  location: 'westus'
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.3'
    settings: {
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: 'true'
      ScheduledScanSettings: {
        isEnabled: 'true'
        day: '7'
        time: '120'
        scanType: 'Quick'
      }
      Exclusions: {
        Paths: extensions_IaaSAntimalware_Paths
        Extensions: extensions_IaaSAntimalware_Extensions
        Processes: extensions_IaaSAntimalware_Processes
      }
    }
  }
}

