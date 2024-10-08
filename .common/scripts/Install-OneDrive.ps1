param(
    [string]$APIVersion,
    [string]$BlobStorageSuffix,
    [string]$BuildDir,
    [string]$UserAssignedIdentityClientId,
    [string]$Uri
)

$ErrorActionPreference = "Stop"

$SoftwareName = 'OneDrive'

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
Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
$RegPath = 'HKLM:\SOFTWARE\Microsoft\OneDrive'
If (Test-Path -Path $RegPath) {
    If (Get-ItemProperty -Path $RegPath -Name AllUsersInstall -ErrorAction SilentlyContinue) {
        $AllUsersInstall = Get-ItemPropertyValue -Path $RegPath -Name AllUsersInstall
    }
}
If ($AllUsersInstall -eq '1') {
    Write-OutputWithTimeStamp "$SoftwareName is already setup per-machine. Quiting."
}
Else {
    Write-OutputWithTimeStamp "Starting '$SoftwareName' install script with following Parameters:"
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
    $OneDriveSetup = $DestFile
    #Find existing OneDriveSetup
    $RegPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe'
    If (Test-Path -Path $RegPath) {
        Write-OutputWithTimeStamp "Found Per-Machine Installation, determining uninstallation command."
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
    Write-OutputWithTimeStamp "Running [$Uninstaller $Arguments] to remove any existing versions."
    Start-Process -FilePath $Uninstaller -ArgumentList $Arguments
    If (get-process onedrivesetup) { Wait-Process -Name OneDriveSetup }
    # Set OneDrive for All Users Install
    Write-OutputWithTimeStamp "Setting registry values to indicate a per-machine (AllUsersInstall)"
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\OneDrive" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\OneDrive" -Name AllUsersInstall -PropertyType DWORD -Value 1 -Force | Out-Null
    $Install = Start-Process -FilePath $OneDriveSetup -ArgumentList '/allusers' -Wait -Passthru
    If ($($Install.ExitCode) -eq 0) {
        Write-OutputWithTimeStamp "'$SoftwareName' installed successfully."
    }
    Else {
        Write-Error "'$SoftwareName' install exit code is $($Install.ExitCode)"
    }
    Write-OutputWithTimeStamp "Configuring OneDrive to startup for each user upon logon."
    New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name OneDrive -PropertyType String -Value 'C:\Program Files\Microsoft OneDrive\OneDrive.exe /background' -Force | Out-Null
    Write-OutputWithTimeStamp "Installed OneDrive Per-Machine"
}
Stop-Transcript