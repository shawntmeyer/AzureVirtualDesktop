param(
    [string]$APIVersion,
    [string]$BuildDir,
    [string]$Environment,
    [string]$UserAssignedIdentityClientId,
    [string]$ContainerName,
    [string]$StorageEndpoint,
    [string]$BlobName
)
$SoftwareName = 'Teams'
Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
$TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
$AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
$sku = (Get-ComputerInfo).OsName
$appDir = Join-Path -Path $BuildDir -ChildPath $SoftwareName
New-Item -Path $appDir -ItemType Directory -Force | Out-Null
$destFile = Join-Path -Path $appDir -ChildPath $BlobName
$WebClient = New-Object System.Net.WebClient
$WebClient.Headers.Add('x-ms-version', '2017-11-09')
$webClient.Headers.Add("Authorization", "Bearer $AccessToken")
$webClient.DownloadFile("$StorageEndpoint$ContainerName/$BlobName", "$destFile")
Start-Sleep -seconds 10
If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $BlobName"; Exit 1 }
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
if (($Sku).Contains('multi')) {
    $msiArgs = 'ALLUSER=1 ALLUSERS=1'
}
else {
    $msiArgs = 'ALLUSERS=1'
}
Start-Process -FilePath msiexec.exe -ArgumentList "/i $teamsFile /quiet /qn /norestart /passive $msiArgs" -Wait -PassThru | Out-Null
Switch ($Environment) {
    "USSec" {
        $CloudType = 5
    }
    "USNat" {
        $CloudType = 6
    }
}
If ($CloudType) {
    Start-Process -FilePath reg.exe -ArgumentList "LOAD HKLM\Default $env:SystemDrive\Users\Default\ntuser.dat" -Wait
    $Result = Start-Process -FilePath reg.exe -ArgumentList "ADD HKLM\Default\SOFTWARE\Microsoft\Office\16.0\Teams /n CloudType /t REG_DWORD /v $CloudType /f" -Wait -PassThru
    $Result.Handle.Close()
    [gc]::Collect()
    $Result = Start-Process -FilePath reg.exe -ArgumentList "UNLOAD HKLM\Default" -Wait -PassThru
}
Write-Output "Installed Teams"
Stop-Transcript