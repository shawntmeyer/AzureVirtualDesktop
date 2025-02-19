param imageTemplateName string = 'test9'
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

var masterScriptContent = '''
<#
    .DESCRIPTION
    Main script to perform customizations via the Azure VM Image Builder Service. This script is used to download and execute customizers on the VM image being built and is significantly
    faster than using individual customizers scripts within the image template because the VM directly performs the download versus the Azure Image Builder service performing the download and
    then sending the download to the VM. This script is used in the 'Customize' phase of the image template.

    .PARAMETER APIVersion
    The API version to use to get an access token for the storage account(s) via the VM Instance Metadata Service. Default is '2018-02-01'.

    .PARAMETER BlobStorageSuffix
    The suffix of the blob storage account of the azure environment where you are building the image. Default is 'core.windows.net'.  For Azure US Government, use 'core.usgovcloudapi.net'.

    .PARAMETER Customizers
    A JSON formatted array of customizers to execute. Each customizer is an object with the following keys:
    - Name: The name of the customizer. (required)
    - Uri: The URI of the customizer. (required)
    - Arguments: The arguments to pass to the customizer. (optional)

    .PARAMETER UserAssignedIdentityClientId
    The client ID of the user assigned identity to use to get an access token for the storage account(s) via the VM Instance Metadata Service.
#>

param(
    [string]$APIVersion = '2018-02-01',
    [string]$BlobStorageSuffix,
    [string]$Customizers = '[]',
    [string]$UserAssignedIdentityClientId
)
$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
Start-Transcript -Path "$env:SystemRoot\Logs\$($Script:Name).log" -Force
Write-Output "Starting '$PSCommandPath'."
Write-Output "Current working dir: $((Get-Location).Path)"
[array]$Customizers = $Customizers | ConvertFrom-Json
ForEach ($Customizer in $Customizers) {
    $Name = $Customizer.Name
    $Uri = $Customizer.Uri
    $Arguments = $Customizer.Arguments
    Write-Output "Processing '$Name' customizer."
    $TempDir = Join-Path $Env:TEMP -ChildPath $Name
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
    $WebClient = New-Object System.Net.WebClient
    If ($Uri -match $BlobStorageSuffix -and $UserAssignedIdentityClientId -ne '') {
        $StorageEndpoint = ($Uri -split '://')[0] + '://' + ($Uri -split '/')[2] + '/'
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $WebClient.Headers.Add('x-ms-version', '2017-11-09')
        $WebClient.Headers.Add("Authorization", "Bearer $AccessToken")
    }
    Write-Output "Downloading '$Uri' to '$TempDir'."
    $SourceFileName = ($Uri -Split '/')[-1]
    $DestFile = Join-Path -Path $TempDir -ChildPath $SourceFileName
    $WebClient.DownloadFile("$Uri", "$DestFile")
    Start-Sleep -Seconds 5
    $WebClient = $null
    If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $SourceFileName"; Exit 1 }
    Write-Output 'Finished downloading'
    $Extension = [System.IO.Path]::GetExtension($DestFile).ToLower().Replace('.', '')
    switch ($Extension) {
        'exe' {
            If ($Arguments) {
                Write-Output "Executing '$DestFile $Arguments'"
                Start-Process -FilePath $DestFile -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
            } Else {
                Write-Output "Executing '$DestFile'"
                Start-Process -FilePath $DestFile -NoNewWindow -Wait -PassThru
            }
        }
        'msi' {
            If ($Arguments) {
                If ($Arguments -notcontains $SourceFileName) {
                    $Arguments = "/i $DestFile $Arguments"
                }
                Write-Output "Executing 'msiexec.exe $Arguments'"
                Start-Process -FilePath msiexec.exe -ArgumentList $Arguments -Wait
            } Else {
                Write-Output "Executing 'msiexec.exe /i $DestFile /qn'"
                Start-Process -FilePath msiexec.exe -ArgumentList "/i $DestFile /qn" -Wait
            }
        }
        'bat' {
            If ($Arguments) {
                Write-Output "Executing 'cmd.exe $DestFile $Arguments'"
                Start-Process -FilePath cmd.exe -ArgumentList "$DestFile $Arguments" -Wait
            } Else {
                Write-Output "Executing 'cmd.exe $DestFile'"
                Start-Process -FilePath cmd.exe -ArgumentList $DestFile -Wait
            }
        }
        'ps1' {
            If ($Arguments) {
                Write-Output "Calling PowerShell Script '$DestFile' with arguments '$Arguments'"
                & $DestFile $Arguments
            } Else {
                Write-Output "Calling PowerShell Script '$DestFile'"
                & $DestFile
            }
        }
        'zip' {
            $DestinationPath = Join-Path -Path $TempDir -ChildPath $([System.IO.Path]::GetFileNameWithoutExtension($SourceFileName))
            Write-Output "Extracting '$DestFile' to '$DestinationPath'."
            Expand-Archive -Path $DestFile -DestinationPath $DestinationPath -Force
            Write-Output "Finding PowerShell script in root of '$DestinationPath'."
            $PSScript = (Get-ChildItem -Path $DestinationPath -filter '*.ps1').FullName
            If ($PSScript) {
                If ($PSScript.count -gt 1) { $PSScript = $PSScript[0] }
                If ($Arguments) {
                    Write-Output "Calling PowerShell Script '$PSScript' with arguments '$Arguments'"
                    & $PSScript $Arguments
                } Else {
                    Write-Output "Calling PowerShell Script '$PSScript'"
                    & $PSScript
                }
            }
        }
    }
}
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "Ending '$PSCommandPath'."
Stop-Transcript
'''
var masterScriptLines = split(masterScriptContent, '\n')
var inlineScript = concat(
  ['$ScriptContent = @\''],
  masterScriptLines,
  ['\'@', 'Set-Content -Path "${buildDir}\\${masterScriptName}" -Value $ScriptContent']
)

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
        inline: inlineScript
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
