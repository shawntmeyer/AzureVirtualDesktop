param imageTemplateName string = 'test4'
param galleryImageId string = '/subscriptions/70c1bb3a-115f-4300-becd-5f74200999bb/resourceGroups/avd-image-management-usgva-rg/providers/Microsoft.Compute/galleries/avd_usgva_gal/images/vmid-MicrosoftWindowsDesktop-Windows11-win1124h2avd'
param location string = resourceGroup().location
param imagePublisher string = 'MicrosoftWindowsDesktop'
param imageOffer string = 'Windows-11'
param imageSku string = 'win11-24h2-avd'
param userAssignedIdentityResourceId string = '/subscriptions/70c1bb3a-115f-4300-becd-5f74200999bb/resourceGroups/avd-image-management-usgva-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-avd-image-management-va'
param vmSize string = 'Standard_D4ads_v5'
param customizations array = [
  {
    name: 'FSLogix'
    Uri: 'https://saimageassetsusgvaa4a449.blob.core.usgovcloudapi.net/artifacts/FSLogix.zip'
  }
  {
    name: 'LGPO'
    Uri: 'https://saimageassetsusgvaa4a449.blob.core.usgovcloudapi.net/artifacts/LGPO.zip'
  }
]
param osDiskSizeGB int = 127
param subnetId string = '/subscriptions/70c1bb3a-115f-4300-becd-5f74200999bb/resourceGroups/rg-avd-networking-lab-va/providers/Microsoft.Network/virtualNetworks/vnet-avd-lab-va/subnets/sn-avd-jumphosts-lab-va'

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: last(split(userAssignedIdentityResourceId, '/'))
  scope: resourceGroup(split(userAssignedIdentityResourceId, '/')[2], split(userAssignedIdentityResourceId, '/')[4])
}

var buildDir = 'C:\\BuildDir'
var masterScriptName = 'aib_master_script.ps1'
var masterScriptParameters = '-BlobStorageSuffix ${environment().suffixes.storage} -Customizers \'${string(customizations)}\' -UserAssignedIdentity ${userAssignedIdentity.properties.clientId}'

var masterScript = loadFileAsBase64('../.common/artifacts/aib_master_script.ps1')

resource imgTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2023-07-01' = {
  name: imageTemplateName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    vmProfile: {
      osDiskSizeGB: osDiskSizeGB
      userAssignedIdentities: [
        '${userAssignedIdentityResourceId}'
      ]
      vmSize: vmSize
      vnetConfig: !empty(subnetId)
        ? {
            subnetId: subnetId
          }
        : null
    }
    source: {
      type: 'PlatformImage'
      publisher: imagePublisher
      offer: imageOffer
      sku: imageSku
      version: 'latest'
    }
    distribute: [
      {
        type: 'SharedImage'
        #disable-next-line use-resource-id-functions
        galleryImageId: galleryImageId
        replicationRegions: [
          location
        ]
        excludeFromLatest: false
        runOutputName: 'runOutputImageVersion'
      }
    ]
    customize: [
      {
        type: 'PowerShell'
        name: 'powershellcommandscript1'
        inline: [
          'new-item -path ${buildDir} -itemtype directory'
        ]
        runElevated: true
        runAsSystem: true
      }
      {
        type: 'PowerShell'
        name: 'CreateMasterScript'
        inline: [
          '$Script = @"'
          '${masterScript}'
          '"@'
          '$DecodedScript = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Script))'
          'Set-Content -Path "${buildDir}\\${masterScriptName}" -Value $DecodedScript'
        ]
      }      
      {
        type: 'PowerShell'
        name: 'executeMasterScript'
        inline: [
          '${buildDir}\\${masterScriptName} ${masterScriptParameters}'
        ]
        runElevated: true
        runAsSystem: true
      }
      {
        type: 'WindowsRestart'
      }
      {
        type: 'WindowsUpdate'
        updateLimit: 20
      }
      {
        type: 'WindowsRestart'
      }
      {
        type: 'PowerShell'
        name: 'powershellcommand'
        inline: [
          'Remove-Item -Path ${buildDir} -Recurse -Force'
        ]
        runElevated: false
        runAsSystem: false
      }
    ]
  }
  tags: {}
}

output parameters string = masterScriptParameters
