param(
    [string]$APIVersion,
    [string]$BlobStorageSuffix,
    [string]$BuildDir,
    [string]$UserAssignedIdentityClientId,
    [string]$TeamsCloudType,
    [string]$Uri
)

$ErrorActionPreference = 'Stop'

function Write-OutputWithTimeStamp {
    param(
        [parameter(ValueFromPipeline=$True, Mandatory=$True, Position=0)]
        [string]$Message
    )    
    $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
    $Entry = '[' + $Timestamp + '] ' + $Message
    Write-Output $Entry
}
If (!(Test-Path -Path "$env:SystemRoot\Logs\ImageBuild")) { New-Item -Path "$env:SystemRoot\Logs\ImageBuild" -ItemType Directory -Force | Out-Null }

$SoftwareName = 'Teams'
Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
Write-OutputWithTimeStamp "Starting script to install $SoftwareName with the following parameters:"
Write-Output ( $PSBoundParameters | Format-Table -AutoSize )
$WebClient = New-Object System.Net.WebClient
If ($Uri -match $BlobStorageSuffix -and $UserAssignedIdentityClientId -ne '') {
    $StorageEndpoint = ($Uri -split "://")[0] + "://" + ($Uri -split "/")[2] + "/"
    $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
    $AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
    $WebClient.Headers.Add('x-ms-version', '2017-11-09')
    $webClient.Headers.Add("Authorization", "Bearer $AccessToken")
}
$appDir = Join-Path -Path $BuildDir -ChildPath $SoftwareName
New-Item -Path $appDir -ItemType Directory -Force | Out-Null
$SourceFileName = ($Uri -Split "/")[-1]
$DestFile = Join-Path -Path $appDir -ChildPath $SourceFileName
Write-OutputWithTimeStamp "Downloading '$Uri' to '$DestFile'."
$webClient.DownloadFile("$Uri", "$DestFile")
Start-Sleep -Seconds 5
If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $SourceFileName"; Exit 1 }
Expand-Archive -Path $destFile -DestinationPath $appDir -Force
$WebView2File = (Get-ChildItem -Path $appDir -filter 'webview*.exe' -Recurse).FullName
$vcRedistFile = (Get-ChildItem -Path $appDir -filter 'vc*.exe' -Recurse).FullName
$webRTCFile = (Get-ChildItem -Path $appDir -filter '*WebRTC*.msi' -Recurse).FullName
$BootStrapperFile = (Get-ChildItem -Path $appDir -filter '*bootstrapper.exe' -Recurse).FullName
$MSIXFile = (Get-ChildItem -Path $appDir -filter '*.msix' -Recurse).FullName
# Enable media optimizations for Team
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name IsWVDEnvironment -PropertyType DWORD -Value 1 -Force
Write-OutputWithTimeStamp "Enabled media optimizations for Teams"
$VCRedistInstaller = Start-Process -FilePath $vcRedistFile -ArgumentList "/install /quiet /norestart" -Wait -PassThru
If ($($VCRedistInstaller.ExitCode) -eq 0 ) {
    Write-OutputWithTimeStamp "Installed the latest version of Microsoft Visual C++ Redistributable"
}
# Check to see if WebView2 is already installed
If (Test-Path -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}') {
    If (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' -Name pv -ErrorAction SilentlyContinue) {
        $WebView2Installed = $True
        $InstalledVersion = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' -Name pv).pv
        Write-OutputWithTimeStamp "WebView2 Runtime is already installed. Version: $InstalledVersion"
    }
}
If (-not $WebView2Installed) {
    Write-OutputWithTimeStamp "Installing the latest version of the Microsoft WebView2 Runtime"
    $WebView2Installer = Start-Process -FilePath $WebView2File -ArgumentList "/silent /install" -Wait -PassThru
    If ($($WebView2Installer.ExitCode) -eq 0 ) {
        Write-OutputWithTimeStamp "Installed the latest version of the Microsoft WebView2 Runtime"
    }
}

# install the Remote Desktop WebRTC Redirector Service
$WebRTCInstall = Start-Process -FilePath msiexec.exe -ArgumentList "/i $webRTCFile /quiet /qn /norestart /passive" -Wait -PassThru
If ($($WebRTCInstall.ExitCode) -eq 0) {
    Write-OutputWithTimeStamp "Installed the Remote Desktop WebRTC Redirector Service"
}
$TeamsInstall = Start-Process -FilePath "$BootStrapperFile" -ArgumentList "-p -o `"$MSIXFile`"" -Wait -PassThru
If ($($TeamsInstall.ExitCode) -eq 0) {
    Write-OutputWithTimeStamp "Installed Teams successfully."
}
Switch ($TeamsCloudType) {
    "GCC" {
        $CloudType = 2
    }
    "GCCH" {
        $CloudType = 3
    }
    "DOD" {
        $CloudType = 4
    }
    "USSec" {
        $CloudType = 5
    }
    "USNat" {
        $CloudType = 6
    }
    "Gallatin" {
        $CloudType = 7
    }
}
If ($CloudType) {
    $null = Start-Process -FilePath reg.exe -ArgumentList "LOAD HKLM\Default $env:SystemDrive\Users\Default\ntuser.dat" -Wait
    $null = Start-Process -FilePath reg.exe -ArgumentList "ADD HKLM\Default\SOFTWARE\Microsoft\Office\16.0\Teams /n CloudType /t REG_DWORD /v $CloudType /f" -Wait -PassThru
    Start-Sleep -Seconds 5
    [System.GC]::Collect()
    $null = Start-Process -FilePath reg.exe -ArgumentList "UNLOAD HKLM\Default" -Wait -PassThru
}
Write-OutputWithTimeStamp "Completed Installation of all components."
Stop-Transcript