targetScope = 'resourceGroup'

param cloud string
param location string = resourceGroup().location
param userAssignedIdentityClientId string
param logBlobContainerUri string
param storageEndpoint string
param containerName string
param managementVmName string
param imageVmName string
param installFsLogix bool
param fslogixBlobName string
param installAccess bool
param installExcel bool
param installOneNote bool
param installOutlook bool
param installPowerPoint bool
param installProject bool
param installPublisher bool
param installSkypeForBusiness bool
param installTeams bool
param installVirtualDesktopOptimizationTool bool
param installVisio bool
param installWord bool
param installOneDrive bool
param onedriveBlobName string
param customizations array
param vDotBlobName string
param officeBlobName string
param teamsBlobName string
param timeStamp string = utcNow('yyMMddhhmm')
param installUpdates bool
param updateService string
param wsusServer string

var buildDir = 'c:\\BuildDir'

var apiVersion = environment().name == 'USNat' ? '2017-08-01' : '2018-02-01'

var customizers = [for customization in customizations: {
  name: customization.name
  blobName: customization.blobName
  arguments: contains(customization, 'arguments') ? customization.arguments : ''
} ]

resource imageVm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: imageVmName
}

resource managementVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource createBuildDirs 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'create-BuildDir-and-LogDir'
  location: location
  parent: imageVm
  properties: {
    treatFailureAsDeploymentFailure: true
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
    ]
    source: {
      script: '''
        param(
          [string]$BuildDir
        )
        New-Item -Path $BuildDir -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path "$env:SystemRoot\Logs" -ChildPath ImageBuild) -ItemType Directory -Force | Out-Null
      '''
    }
  }
}

@batchSize(1)
resource applications 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = [for customizer in customizers: {
  name: '${customizer.name}'
  location: location
  parent: imageVm
  properties: {
    treatFailureAsDeploymentFailure: true
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-${customizer.name}-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-${customizer.name}-output-${timeStamp}.log'
    parameters: [
      {
        name: 'APIVersion'
        value: apiVersion
      }
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'Blobname'
        value: customizer.blobName
      }
      {
        name: 'installer'
        value: customizer.name
      }
      {
        name: 'Arguments'
        value: customizer.arguments
      }
    ]
    source: {
      script: '''
        param(
          [string]$APIVersion,
          [string]$BuildDir,
          [string]$UserAssignedIdentityClientId,
          [string]$ContainerName,
          [string]$StorageEndpoint,
          [string]$BlobName,
          [string]$Installer,
          [string]$Arguments
        )
        Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$Installer.log" -Force
        If ($Arguments -eq '') {$Arguments = $null}
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $InstallDir = Join-Path $BuildDir -ChildPath $Installer
        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        Write-Output "Downloading $BlobName from $ContainerName with to $InstallDir"
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add('x-ms-version', '2017-11-09')
        $webClient.Headers.Add("Authorization", "Bearer $AccessToken")
        $webClient.DownloadFile("$StorageEndpoint$ContainerName/$BlobName", "$InstallDir\$BlobName")
        Write-Output 'Finished downloading'
      
        Start-Sleep -Seconds 10        
        Set-Location -Path $InstallDir
        if($Blobname -like '*.exe') {
          If ($Arguments) {
            Start-Process -FilePath $InstallDir\$Blobname -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
          } Else {
            Start-Process -FilePath $InstallDir\$Blobname -NoNewWindow -Wait -PassThru
          }
          $status = Get-WmiObject -Class Win32_Product | Where-Object Name -like "*$($installer)*"
          if($status) {
            Write-Output $status.Name "is installed"
          } else {
            Write-Output "$Installer did not install properly, please check arguments"
          }
        }
        if($Blobname -like '*.msi') {
          If ($Arguments) {
            If ($Arguments -notcontains $Blobname) {$Arguments = "/i $Blobname $Arguments"}
            Start-Process -FilePath msiexec.exe -ArgumentList $Arguments -Wait
          } Else {
            Start-Process -FilePath msiexec.exe -ArgumentList "/i $BlobName /qn" -Wait
          }
          $status = Get-WmiObject -Class Win32_Product | Where-Object Name -like "*$($installer)*"
          if($status) {
            Write-Output $status.Name "is installed"
          } else {
            Write-Output $Installer "did not install properly, please check arguments"
          }
        }
        if($Blobname -like '*.bat') {
          If ($Arguments) {
            Start-Process -FilePath cmd.exe -ArgumentList "$BlobName $Arguments" -Wait
          } Else {
            Start-Process -FilePath cmd.exe -ArgumentList "$BlobName" -Wait
          }
        }
        if($Blobname -like '*.ps1') {
          If ($Arguments) {
            & $BlobName $Arguments
          } Else {
            & $BlobName
          }
        }
        if($Blobname -like '*.zip') {
          $destinationPath = Join-Path -Path $InstallDir -ChildPath $([System.IO.Path]::GetFileNameWithoutExtension($Blobname))
          Expand-Archive -Path $InstallDir\$Blobname -DestinationPath $destinationPath -Force
          $PSScript = (Get-ChildItem -Path $destinationPath -filter '*.ps1').FullName
          If ($PSScript.count -gt 1) { $PSScript = $PSScript[0] }
          If ($Arguments) {
            & $PSScript $Arguments
          } Else {          
            & $PSScript
          }
        }
        Stop-Transcript
      '''
    }
  }
  dependsOn: [
    createBuildDirs
  ]
}]

resource fslogix 'Microsoft.Compute/virtualMachines/runCommands@2023-07-01' = if(installFsLogix) {
  name: 'fslogix'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-FSLogix-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-FSLogix-output-${timeStamp}.log'
    parameters: [
      {
        name: 'APIVersion'
        value: apiVersion
      }
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'BlobName'
        value: fslogixBlobName
      }
    ]
    source: {
      script: '''
        param(
          [string]$APIVersion,
          [string]$BuildDir,
          [string]$UserAssignedIdentityClientId,
          [string]$ContainerName,
          [string]$StorageEndpoint,
          [string]$BlobName
        )
        $SoftwareName = 'FSLogix'
        Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
        Write-Output "Starting '$SoftwareName' install."
        Write-Output "Obtaining bearer token for download from Azure Storage Account."
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $appDir = Join-Path -Path $BuildDir -ChildPath $SoftwareName
        New-Item -Path $appDir -ItemType Directory -Force | Out-Null
        $destFile = Join-Path -Path $appDir -ChildPath $BlobName
        Write-Output "Downloading $BlobName from storage."
        Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageEndpoint$ContainerName/$BlobName" -OutFile $destFile
        Start-Sleep -seconds 10
        Write-Output "Extracting Contents of Zip File"
        Expand-Archive -Path $destFile -DestinationPath "$appDir\Temp" -Force
        $FSLogixZip = (Get-ChildItem -Path "$appDir\Temp" -filter '*.zip').FullName
        Write-Output "Found FSLogix Source files: [$FSLogixZip], Extracting contents..."
        Expand-Archive -Path $FSLogixZip -DestinationPath $appDir -Force
        $Installer = (Get-ChildItem -Path $appDir -File -Recurse -Filter 'FSLogixAppsSetup.exe' | Where-Object { $_.FullName -like '*x64*' }).FullName
        Write-Output "Installation file found: [$Installer], executing installation."
        $Install = Start-Process -FilePath $Installer -ArgumentList "/install /quiet /norestart" -Wait -PassThru
        If ($($Install.ExitCode) -eq 0) {
            Write-Output "'Microsoft FSLogix Apps' installed successfully."
        }
        Else {
            Write-Error "The Install exit code is $($Install.ExitCode)"
        }
        Write-Output "Copying the FSLogix ADMX and ADML files to the PolicyDefinitions folders."
        Get-ChildItem -Path $appDir -File -Recurse -Filter '*.admx' | ForEach-Object { Write-Output "Copying $($_.Name)"; Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\" -Force }
        Get-ChildItem -Path $appDir -File -Recurse -Filter '*.adml' | ForEach-Object { Write-Output "Copying $($_.Name)"; Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\en-us\" -Force }
        Write-Output "Installation complete."
        Stop-Transcript     
      '''
    }
  }
  dependsOn: [
    createBuildDirs
    applications
  ]
}

resource office 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if(installAccess || installExcel || installOneNote || installOutlook || installPowerPoint || installProject || installPublisher || installSkypeForBusiness || installVisio || installWord) {
  name: 'install-office'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Office-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Office-output-${timeStamp}.log'
    parameters: [
      {
        name: 'APIVersion'
        value: apiVersion
      }
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'InstallAccess'
        value: string(installAccess)
      }
      {
        name: 'InstallWord'
        value: string(installWord)
      }
      {
        name: 'InstallExcel'
        value: string(installExcel)
      }
      {
        name: 'InstallOneNote'
        value: string(installOneNote)
      }
      {
        name: 'InstallOutlook'
        value: string(installOutlook)
      }
      {
        name: 'InstallPowerPoint'
        value: string(installPowerPoint)
      }
      {
        name: 'InstallProject'
        value: string(installProject)
      }
      {
        name: 'InstallPublisher'
        value: string(installPublisher)
      }
      {
        name: 'InstallSkypeForBusiness'
        value: string(installSkypeForBusiness)
      }
      {
        name: 'InstallVisio'
        value: string(installVisio)
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'BlobName'
        value: officeBlobName
      }
    ]
    source: {
      script: '''      
        param(
          [string]$APIVersion,
          [string]$BuildDir,
          [string]$InstallAccess,
          [string]$InstallExcel,
          [string]$InstallOutlook,
          [string]$InstallProject,
          [string]$InstallPublisher,
          [string]$InstallSkypeForBusiness,
          [string]$InstallVisio,
          [string]$InstallWord,
          [string]$InstallOneNote,
          [string]$InstallPowerPoint,
          [string]$UserAssignedIdentityClientId,
          [string]$ContainerName,
          [string]$StorageEndpoint,
          [string]$BlobName
        )
        $SoftwareName = 'Office-365'
        Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
        Write-Output "Installing '$SoftwareName'."
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $sku = (Get-ComputerInfo).OsName
        $appDir = Join-Path -Path $BuildDir -ChildPath $SoftwareName
        New-Item -Path $appDir -ItemType Directory -Force | Out-Null  
        $ErrorActionPreference = "Stop"
        $destFile = Join-Path -Path $appDir -ChildPath $BlobName
        Invoke-WebRequest -Headers @{"x-ms-version" = "2017-11-09"; Authorization = "Bearer $AccessToken" } -Uri "$StorageEndpoint$ContainerName/$BlobName" -OutFile $destFile
        Start-Sleep -Seconds 10
        Expand-Archive -Path $destFile -DestinationPath "$appDir\Temp" -Force
        $Setup = (Get-ChildItem -Path "$appDir\Temp" -Filter 'setup*.exe' -Recurse -File).FullName
        If (-not($Setup)) {
          $DeploymentTool = (Get-ChildItem -Path $appDir\Temp -Filter 'OfficeDeploymentTool*.exe' -Recurse -File).FullName
          Start-Process -FilePath $DeploymentTool -ArgumentList "/extract:`"$appDir\ODT`" /quiet /passive /norestart" -Wait -PassThru | Out-Null
          Write-Output "Downloaded & extracted the Office 365 Deployment Toolkit"
          $setup = (Get-ChildItem -Path "$appDir\ODT" -Filter '*setup*.exe').FullName
        }
        Write-Output "Dynamically creating $SoftwareName configuration file for setup."
        $configFile = Join-Path -Path $appDir -ChildPath 'office365x64.xml'
        $null = Set-Content $configFile '<Configuration>'
        $null = Add-Content $configFile '  <Add OfficeClientEdition="64" Channel="MonthlyEnterprise">'
        $null = Add-Content $configFile '    <Product ID="O365ProPlusRetail">'
        $null = Add-Content $configFile '      <Language ID="en-us" />'
        $null = Add-Content $configFile '      <ExcludeApp ID="Groove" />'
        $null = Add-Content $configFile '      <ExcludeApp ID="OneDrive" />'
        $null = Add-Content $configFile '      <ExcludeApp ID="Teams" />'
        if ($InstallAccess -ne 'True') {
          $null = Add-Content $configFile '      <ExcludeApp ID="Access" />'
        }
        if ($InstallExcel -ne 'True') {
          $null = Add-Content $configFile '      <ExcludeApp ID="Excel" />'
        }
        if ($InstallOneNote -ne 'True') {
          $null = Add-Content $configFile '      <ExcludeApp ID="OneNote" />'
        }
        if ($InstallOutlook -ne 'True') {
          $null = Add-Content $configFile '      <ExcludeApp ID="Outlook" />'
        }
        if ($InstallPowerPoint -ne 'True') {
          $null = Add-Content $configFile '      <ExcludeApp ID="PowerPoint" />'
        }
        if ($InstallPublisher -ne 'True') {
          $null = Add-Content $configFile '      <ExcludeApp ID="Publisher" />'
        }
        if ($InstallSkypeForBusiness -ne 'True') {
          $null = Add-Content $configFile '      <ExcludeApp ID="Lync" />'
        }
        if ($InstallWord -ne 'True') {
          $null = Add-Content $configFile '      <ExcludeApp ID="Word" />'
        }
        $null = Add-Content $configFile '    </Product>'
        if ($InstallProject -eq 'True') {
          $null = Add-Content $configFile '    <Product ID="ProjectProRetail"><Language ID="en-us" /></Product>'
        }
        if ($InstallVisio -eq 'True') {
          $null = Add-Content $configFile '    <Product ID="VisioProRetail"><Language ID="en-us" /></Product>'
        }
        $null = Add-Content $configFile '  </Add>'
        if (($Sku).Contains("multi") -eq "true") {
          $null = Add-Content $configFile '  <Property Name="SharedComputerLicensing" Value="1" />'
        }
        $null = Add-Content $configFile '  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />'
        $null = Add-Content $configFile '  <Updates Enabled="FALSE" />'
        $null = Add-Content $configFile '  <Display Level="None" AcceptEULA="TRUE" />'
        $null = Add-Content $configFile '</Configuration>'
        Write-Output "Starting setup process."
        $Install = Start-Process -FilePath $setup -ArgumentList "/configure `"$configFile`"" -Wait -PassThru -ErrorAction "Stop"
        If ($($Install.ExitCode) -eq 0) {
          Write-Output "'$SoftwareName' installed successfully."
        }
        Else {
          Write-Error "'$SoftwareName' install exit code is $($Install.ExitCode)"
        }
        Stop-Transcript
      '''
    }
  }
  dependsOn: [
    createBuildDirs
    fslogix
    applications
  ]
}

resource onedrive 'Microsoft.Compute/virtualMachines/runCommands@2023-07-01' = if(installOneDrive) {
  name: 'onedrive'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-OneDrive-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-OneDrive-output-${timeStamp}.log'
    parameters: [
      {
        name: 'APIVersion'
        value: apiVersion
      }
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'BlobName'
        value: onedriveBlobName
      }
    ]
    source: {
      script: '''
        param(
          [string]$APIVersion,
          [string]$BuildDir,
          [string]$UserAssignedIdentityClientId,
          [string]$ContainerName,
          [string]$StorageEndpoint,
          [string]$BlobName
        )
        $SoftwareName = 'OneDrive'
        Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
        $RegPath = 'HKLM:\SOFTWARE\Microsoft\OneDrive'
        If (Test-Path -Path $RegPath) {
          If (Get-ItemProperty -Path $RegPath -Name AllUsersInstall -ErrorAction SilentlyContinue) {
            $AllUsersInstall = Get-ItemPropertyValue -Path $RegPath -Name AllUsersInstall
          }
        }
        If ($AllUsersInstall -eq '1') {
          Write-Output "$SoftwareName is already setup per-machine. Quiting."
        } Else {
          Write-Output "Obtaining bearer token for download from Azure Storage Account."
          $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
          $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
          $appDir = Join-Path -Path $BuildDir -ChildPath 'OneDrive'
          New-Item -Path $appDir -ItemType Directory -Force | Out-Null
          $destFile = Join-Path -Path $appDir -ChildPath 'OneDrive.zip'
          Write-Output "Downloading $BlobName from storage."
          Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageEndpoint$ContainerName/$BlobName" -OutFile $destFile
          Start-Sleep -Seconds 10
          Expand-Archive -Path $destFile -DestinationPath $appDir -Force
          $onedrivesetup = (Get-ChildItem -Path $appDir -filter 'OneDrive*.exe' -Recurse).FullName
          #Find existing OneDriveSetup
          $RegPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe'
          If (Test-Path -Path $RegPath) {
            Write-Output "Found Per-Machine Installation, determining uninstallation command."
            If (Get-ItemProperty -Path $RegPath -name UninstallString -ErrorAction SilentlyContinue) {
              $UninstallString = (Get-ItemPropertyValue -Path $RegPath -Name UninstallString).toLower()
              $OneDriveSetupindex = $UninstallString.IndexOf('onedrivesetup.exe') + 17
              $Uninstaller = $UninstallString.Substring(0,$OneDriveSetupindex)
              $Arguments = $UninstallString.Substring($OneDriveSetupindex).replace('  ', ' ').trim()
            }
          } Else {
            $Uninstaller = $OneDriveSetup
            $Arguments = '/uninstall'
          }    
          # Uninstall existing version
          Write-Output "Running [$Uninstaller $Arguments] to remove any existing versions."
          Start-Process -FilePath $Uninstaller -ArgumentList $Arguments
          If (get-process onedrivesetup) {Wait-Process -Name OneDriveSetup}
          # Set OneDrive for All Users Install
          Write-Output "Setting registry values to indicate a per-machine (AllUsersInstall)"
          New-Item -Path "HKLM:\SOFTWARE\Microsoft\OneDrive" -Force | Out-Null
          New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\OneDrive" -Name AllUsersInstall -PropertyType DWORD -Value 1 -Force | Out-Null
          $Install = Start-Process -FilePath $onedrivesetup -ArgumentList '/allusers' -Wait -Passthru
          If ($($Install.ExitCode) -eq 0) {
            Write-Output "'$SoftwareName' installed successfully."
          }
          Else {
            Write-Error "'$SoftwareName' install exit code is $($Install.ExitCode)"
          }
          Write-Output "Configuring OneDrive to startup for each user upon logon."
          New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name OneDrive -PropertyType String -Value 'C:\Program Files\Microsoft OneDrive\OneDrive.exe /background' -Force | Out-Null
          Write-Output "Installed OneDrive Per-Machine"
        }
        Stop-Transcript
      '''
    }
  }
  dependsOn: [
    createBuildDirs
    applications
    fslogix
    office
  ]
}

resource teams 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installTeams) {
  name: 'teams'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Teams-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Teams-output-${timeStamp}.log'
    parameters: [
      {
        name: 'APIVersion'
        value: apiVersion
      }
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'BlobName'
        value: teamsBlobName
      }
    ]
    source: {
      script: '''
        param(
          [string]$APIVersion,
          [string]$BuildDir,
          [string]$UserAssignedIdentityClientId,
          [string]$ContainerName,
          [string]$StorageEndpoint,
          [string]$BlobName
        )
        $SoftwareName = 'Teams'
        Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $sku = (Get-ComputerInfo).OsName
        $appDir = Join-Path -Path $BuildDir -ChildPath $SoftwareName
        New-Item -Path $appDir -ItemType Directory -Force | Out-Null
        $destFile = Join-Path -Path $appDir -ChildPath $BlobName
        Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageEndpoint$ContainerName/$BlobName" -OutFile $destFile
        Start-Sleep -Seconds 10
        Expand-Archive -Path $destFile -DestinationPath $appDir -Force
        $vcRedistFile = (Get-ChildItem -Path $appDir -filter 'vc*.exe' -Recurse).FullName
        $webRTCFile = (Get-ChildItem -Path $appDir -filter '*WebRTC*.msi' -Recurse).FullName
        $teamsFile = (Get-ChildItem -Path $appDir -filter '*Teams*.msi' -Recurse).FullName
        # Enable media optimizations for Team
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Force
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name IsWVDEnvironment -PropertyType DWORD -Value 1 -Force
        Write-Output "Enabled media optimizations for Teams"
        $ErrorActionPreference = "Stop"
        Start-Process -FilePath  $vcRedistFile -ArgumentList "/install /quiet /norestart" -Wait -PassThru | Out-Null
        Write-Output "Installed the latest version of Microsoft Visual C++ Redistributable"
        # install the Remote Desktop WebRTC Redirector Service
        Start-Process -FilePath msiexec.exe -ArgumentList "/i  $webRTCFile /quiet /qn /norestart /passive" -Wait -PassThru | Out-Null
        Write-Output "Installed the Remote Desktop WebRTC Redirector Service"
        # Install Teams
        if(($Sku).Contains('multi')){
            $msiArgs = 'ALLUSER=1 ALLUSERS=1'
        } else {
            $msiArgs = 'ALLUSERS=1'
        }
        Start-Process -FilePath msiexec.exe -ArgumentList "/i $teamsFile /quiet /qn /norestart /passive $msiArgs" -Wait -PassThru | Out-Null
        Write-Output "Installed Teams"
        Stop-Transcript
      '''
    }
  }
  dependsOn: [
    createBuildDirs
    applications
    fslogix
    office
    onedrive
  ]
}

resource firstImageVmRestart 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'restart-vm-1'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: false
    parameters: [
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'imageVmRg'
        value: split(imageVm.id, '/')[4]
      }
      {
        name: 'imageVmName'
        value: imageVm.name
      }
      {
        name: 'Environment'
        value: cloud
      }
    ]
    source: {
      script: '''
        param(
          [string]$UserAssignedIdentityClientId,
          [string]$imageVmRg,
          [string]$imageVmName,
          [string]$Environment
        )
        # Connect to Azure
        Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -Environment $Environment # Run on the virtual machine
        # Restart VM
        Restart-AzVM -Name $imageVmName -ResourceGroupName $imageVmRg        
        $lastProvisioningState = ""
        $provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
        $condition = ($provisioningState -eq "PowerState/running")
        while (!$condition) {
          $lastProvisioningState = $provisioningState    
          Start-Sleep -Seconds 5
          $provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
        }
      '''
    }
  }
  dependsOn: [
    createBuildDirs
    applications
    fslogix
    office
    teams
  ]
}

resource microsoftUpdates 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if(installUpdates) {
  name: 'install-microsoft-updates'
  location: location
  parent: imageVm
  properties: {
    asyncExecution: false
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Install-Updates-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Install-Updates-output-${timeStamp}.log'
    parameters: updateService == 'WSUS' ? [
      {
        name: 'Service'
        value: updateService
      }
      {
        name: 'WSUSServer'
        value: wsusServer
      }
    ] : [
      {
        name: 'Service'
        value: updateService
      }
    ]   
    source: {
      script: '''
        param (
          # The App Name to pass to the WUA API as the calling application.
          [Parameter()]
          [String]$AppName = "Windows Update API Script",
          # The search criteria to be used.
          [Parameter()]
          [String]$Criteria = "IsInstalled=0 and Type='Software' and IsHidden=0",
          [Parameter()]
          [bool]$ExcludePreviewUpdates = $true,
          # Default service (WSUS if machine is configured to use it, or MU if opted in, or WU otherwise.)
          [Parameter()]
          [ValidateSet("WU","MU","WSUS","DCAT","STORE","OTHER")]
          [string]$Service = 'MU',
          # The http/https fqdn for the Windows Server Update Server
          [Parameter()]
          [string]$WSUSServer
        )
        
        Function ConvertFrom-InstallationResult {
        [CmdletBinding()]
            param (
                [Parameter()]
                [int]$Result
            )        
            switch ($Result) {
                2 { $Text = 'Succeeded' }
                3 { $Text = 'Succeeded with errors' }
                4 { $Text = 'Failed' }
                5 { $Text = 'Cancelled' }
                Default { $Text = "Unexpected ($Result)"}
            }        
            Return $Text
        }
        Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\Install-Updates.log"
        Switch ($Service.ToUpper()) {
            'WU' { $ServerSelection = 2 }
            'MU' { $ServerSelection = 3; $ServiceId = "7971f918-a847-4430-9279-4a52d1efe18d" }
            'WSUS' { $ServerSelection = 1 }
            'DCAT' { $ServerSelection = 3; $ServiceId = "855E8A7C-ECB4-4CA3-B045-1DFA50104289" }
            'STORE' { $serverSelection = 3; $ServiceId = "117cab2d-82b1-4b5a-a08c-4d62dbee7782" }
            'OTHER' { $ServerSelection = 3; $ServiceId = $Service }
        }        
        If ($Service -eq 'MU') {
            $UpdateServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
            $UpdateServiceManager.ClientApplicationID = $AppName
            $UpdateServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "")
            $null = cmd /c reg.exe ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AllowMUUpdateService /t REG_DWORD /d 1 /f '2>&1'
            Write-Output "Added Registry entry to configure Microsoft Update. Exit Code: [$LastExitCode]"
        } Elseif ($Service -eq 'WSUS' -and $WSUSServer) {
            $null = cmd /c reg.exe ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v WUServer /t REG_SZ /d $WSUSServer /f '2>&1'
            $null = cmd /c reg.exe ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v WUStatusServer /t REG_SZ /d $WSUSServer /f '2>&1'
            Write-Output "Added Registry entry to configure WSUS Server. Exit Code: [$LastExitCode]"
        }        
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSession.ClientApplicationID = $AppName   
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        $UpdateSearcher.ServerSelection = $ServerSelection
        If ($ServerSelection -eq 3) {
            $UpdateSearcher.ServiceId = $ServiceId
        }
        Write-Output "Searching for Updates..."
        $SearchResult = $UpdateSearcher.Search($Criteria)
        If ($SearchResult.Updates.Count -eq 0) {
            Write-Output "There are no applicable updates."
            Write-Output "Now Exiting"
            Exit $ExitCode
        }
        Write-Output "List of applicable items found for this computer:"
        For ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
            $Update = $SearchResult.Updates[$i]
            Write-Output "$($i + 1) > $($update.Title)"
        }
        $AtLeastOneAdded = $false
        $ExclusiveAdded = $false   
        $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
        Write-Output "Checking search results:"
        For ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
            $Update = $SearchResult.Updates[$i]
            $AddThisUpdate = $false        
            If ($ExclusiveAdded) {
                Write-Output "$($i + 1) > skipping: '$($update.Title)' because an exclusive update has already been selected."
            } Else {
                $AddThisUpdate = $true
            }        
            if ($ExcludePreviewUpdates -and $update.Title -like '*Preview*') {
                Write-Output "$($i + 1) > Skipping: '$($update.Title)' because it is a preview update."
                $AddThisUpdate = $false
            }        
            If ($AddThisUpdate) {
                $PropertyTest = 0
                $ErrorActionPreference = 'SilentlyContinue'
                $PropertyTest = $Update.InstallationBehavior.Impact
                $ErrorActionPreference = 'Stop'
                If ($PropertyTest -eq 2) {
                    If ($AtLeastOneAdded) {
                        Write-Output "$($i + 1) > skipping: '$($update.Title)' because it is exclusive and other updates are being installed first."
                        $AddThisUpdate = $false
                    }
                }
            }
            If ($AddThisUpdate) {
                Write-Output "$($i + 1) > adding: '$($update.Title)'"
                $UpdatesToDownload.Add($Update) | out-null
                $AtLeastOneAdded = $true
                $ErrorActionPreference = 'SilentlyContinue'
                $PropertyTest = $Update.InstallationBehavior.Impact
                $ErrorActionPreference = 'Stop'
                If ($PropertyTest -eq 2) {
                    Write-Output "This update is exclusive; skipping remaining updates"
                    $ExclusiveAdded = $true
                }
            }
        }        
        $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        Write-Output "Downloading updates..."
        $Downloader = $UpdateSession.CreateUpdateDownloader()
        $Downloader.Updates = $UpdatesToDownload
        $Downloader.Download()
        Write-Output "Successfully downloaded updates:"        
        For ($i = 0; $i -lt $UpdatesToDownload.Count; $i++) {
            $Update = $UpdatesToDownload[$i]
            If ($Update.IsDownloaded -eq $true) {
                Write-Output "$($i + 1) > $($update.title)"
                $UpdatesToInstall.Add($Update) | out-null
            }
        }        
        If ($UpdatesToInstall.Count -gt 0) {
            Write-Output "Now installing updates..."
            $Installer = $UpdateSession.CreateUpdateInstaller()
            $Installer.Updates = $UpdatesToInstall
            $InstallationResult = $Installer.Install()
            $Text = ConvertFrom-InstallationResult -Result $InstallationResult.ResultCode
            Write-Output "Installation Result: $($Text)"        
            If ($InstallationResult.RebootRequired) {
                Write-Output "Atleast one update requires a reboot to complete the installation."
            }
        }
        If ($service -eq 'MU') {
            Reg.exe DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AllowMUUpdateService /f
        } Elseif ($Service -eq 'WSUS' -and $WSUSServer) {
            reg.exe DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v WUServer /f
            reg.exe DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v WUStatusServer /f
        }
        Stop-Transcript
      '''
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    firstImageVmRestart
  ]
}

resource secondImageVmRestart 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if(installUpdates) {
  name: 'restart-vm-2'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: false
    parameters: [
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'imageVmRg'
        value: split(imageVm.id, '/')[4]
      }
      {
        name: 'imageVmName'
        value: imageVm.name
      }
      {
        name: 'Environment'
        value: cloud
      }
    ]
    source: {
      script: '''
        param(
          [string]$UserAssignedIdentityClientId,
          [string]$imageVmRg,
          [string]$imageVmName,
          [string]$Environment
        )
        # Connect to Azure
        Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -Environment $Environment # Run on the virtual machine
        # Restart VM
        Restart-AzVM -Name $imageVmName -ResourceGroupName $imageVmRg        
        $lastProvisioningState = ""
        $provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
        $condition = ($provisioningState -eq "PowerState/running")
        while (!$condition) {
          if ($lastProvisioningState -ne $provisioningState) {
            Write-Output $imageVmName "under" $imageVmRg "is" $provisioningState "(waiting for state change)"
          }
          $lastProvisioningState = $provisioningState      
          Start-Sleep -Seconds 5
          $provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
        }
        Write-Output $imageVmName "under" $imageVmRg "is" $provisioningState
      '''
    }
  }
  dependsOn: [
    microsoftUpdates
  ]
}

resource vdot 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installVirtualDesktopOptimizationTool) {
  name: 'vdot'
  location: location
  parent: imageVm
  properties: {
    treatFailureAsDeploymentFailure: true
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-vdot-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-vdot-output-${timeStamp}.log'
    parameters: [
      {
        name: 'APIVersion'
        value: apiVersion
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }

      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'BlobName'
        value: vDotBlobName
      }
      {
        name: 'BuildDir'
        value: buildDir
      }
    ]
    source: {
      script: '''
        param(
          [string]$APIVersion,
          [string]$UserAssignedIdentityClientId,
          [string]$ContainerName,
          [string]$StorageEndpoint,
          [string]$BlobName,
          [string]$BuildDir    
        )
        Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\VDOT.log" -Force
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $ZIP = Join-Path -Path $BuildDir -ChildPath $BlobName
        Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageEndpoint$ContainerName/$BlobName" -OutFile $ZIP
        Start-Sleep -Seconds 10
        Unblock-File -Path $ZIP
        $VDOTDir = Join-Path -Path $BuildDir -ChildPath 'VDOT'
        Expand-Archive -LiteralPath $ZIP -DestinationPath $VDOTDir -Force
        $Path = (Get-ChildItem -Path $VDOTDir -Recurse | Where-Object {$_.Name -eq "Windows_VDOT.ps1"}).FullName
        $Script = Get-Content -Path $Path
        $ScriptUpdate = $Script.Replace("Set-NetAdapterAdvancedProperty","#Set-NetAdapterAdvancedProperty")
        $ScriptUpdate | Set-Content -Path $Path
        & $Path -Optimizations @("AppxPackages","Autologgers","DefaultUserSettings","LGPO","NetworkOptimizations","ScheduledTasks","Services","WindowsMediaPlayer") -AdvancedOptimizations @("Edge","RemoveLegacyIE") -AcceptEULA
        Write-Output "Optimized the operating system using the Virtual Desktop Optimization Tool"
        Stop-Transcript
      '''
    }
    timeoutInSeconds: 640
  }
  dependsOn: [
    secondImageVmRestart
  ]
}

resource removeBuildDir 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'remove-BuildDir'
  location: location
  parent: imageVm
  properties: {
    treatFailureAsDeploymentFailure: true
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
    ]
    source: {
      script: '''
        param(
          [string]$BuildDir
        )
        Remove-Item -Path $BuildDir -Recurse -Force | Out-Null
      '''
    }
  }
  dependsOn: [
    secondImageVmRestart
    vdot
  ]
}

resource thirdImageVmRestart 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installVirtualDesktopOptimizationTool) {
  name: 'restart-vm-3'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: false
    parameters: [
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ImageVmRg'
        value: split(imageVm.id, '/')[4]
      }
      {
        name: 'ImageVmName'
        value: imageVm.name
      }
      {
        name: 'Environment'
        value: cloud
      }
    ]
    source: {
      script: '''
        param(
          [string]$UserAssignedIdentityClientId,
          [string]$ImageVmRg,
          [string]$ImageVmName,
          [string]$Environment
        )
        # Connect to Azure
        Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -Environment $Environment
        Restart-AzVM -Name $imageVmName -ResourceGroupName $imageVmRg        
        $lastProvisioningState = ""
        $provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
        $condition = ($provisioningState -eq "PowerState/running")
        while (!$condition) {
          if ($lastProvisioningState -ne $provisioningState) {
            Write-Output $imageVmName "under" $imageVmRg "is" $provisioningState "(waiting for state change)"
          }
          $lastProvisioningState = $provisioningState      
          Start-Sleep -Seconds 5
          $provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
        }
        Write-Output $imageVmName "under" $imageVmRg "is" $provisioningState
      '''
    }
  }
  dependsOn: [
    removeBuildDir
  ]
}

resource sysprep 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'sysprep'
  location: location
  parent: imageVm
  properties: {
    asyncExecution: false
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
        clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Sysprep-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
        clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Sysprep-output-${timeStamp}.log'
    source: {
      script: '''
        $Services = 'RdAgent', 'WindowsTelemetryService', 'WindowsAzureGuestAgent'        
        ForEach ($Service in $Services) {
            If (Get-Service | Where-Object {$_.Name -eq $Service}) {
                While ((Get-Service -Name $Service).Status -ne 'Running') {
                    Write-Output ">>> Waiting for $Service to start..."
                    Start-Sleep -Seconds 5
                }
            }
        }
        $Files = "$env:SystemRoot\System32\sysprep\unattend.xml", "$env:SystemRoot\Panther\Unattend.xml"
        ForEach ($file in $Files) {
            if (Test-Path -Path $File) {
              Write-Output ">>> Removing $file"
              Remove-Item $file -Force
            }
        }
        Write-Output '>>> Sysprepping VM ...'
        Start-Process -FilePath "C:\Windows\System32\Sysprep\Sysprep.exe" -ArgumentList "/generalize /oobe /quit /mode:vm" -Wait
        while($true) {
            $imageState = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State).ImageState
            Write-Output $imageState
            if ($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { break }
            Start-Sleep -s 5
        }
        Write-Output ">>> Sysprep complete ..."
      '''
    }
  }
  dependsOn: [
    removeBuildDir
    thirdImageVmRestart
  ]
}
