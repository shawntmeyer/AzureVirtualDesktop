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
}
Else {
    Write-Output "Obtaining bearer token for download from Azure Storage Account."
    $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
    $AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
    $appDir = Join-Path -Path $BuildDir -ChildPath 'OneDrive'
    New-Item -Path $appDir -ItemType Directory -Force | Out-Null
    $DestFile = Join-Path -Path $appDir -ChildPath $BlobName
    Write-Output "Downloading $BlobName from storage."
    $WebClient = New-Object System.Net.WebClient
    $WebClient.Headers.Add('x-ms-version', '2017-11-09')
    $webClient.Headers.Add("Authorization", "Bearer $AccessToken")
    $webClient.DownloadFile("$StorageEndpoint$ContainerName/$BlobName", "$destFile")
    Start-Sleep -seconds 10
    If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $BlobName"; Exit 1 }
    $OneDriveSetup = $DestFile
    #Find existing OneDriveSetup
    $RegPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe'
    If (Test-Path -Path $RegPath) {
        Write-Output "Found Per-Machine Installation, determining uninstallation command."
        If (Get-ItemProperty -Path $RegPath -name UninstallString -ErrorAction SilentlyContinue) {
            $UninstallString = (Get-ItemPropertyValue -Path $RegPath -Name UninstallString).toLower()
            $OneDriveSetupindex = $UninstallString.IndexOf('onedrivesetup.exe') + 17
            $Uninstaller = $UninstallString.Substring(0, $OneDriveSetupindex)
            $Arguments = $UninstallString.Substring($OneDriveSetupindex).replace('  ', ' ').trim()
        }
    }
    Else {
        $Uninstaller = $OneDriveSetup
        $Arguments = '/uninstall'
    }    
    # Uninstall existing version
    Write-Output "Running [$Uninstaller $Arguments] to remove any existing versions."
    Start-Process -FilePath $Uninstaller -ArgumentList $Arguments
    If (get-process onedrivesetup) { Wait-Process -Name OneDriveSetup }
    # Set OneDrive for All Users Install
    Write-Output "Setting registry values to indicate a per-machine (AllUsersInstall)"
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\OneDrive" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\OneDrive" -Name AllUsersInstall -PropertyType DWORD -Value 1 -Force | Out-Null
    $Install = Start-Process -FilePath $OneDriveSetup -ArgumentList '/allusers' -Wait -Passthru
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