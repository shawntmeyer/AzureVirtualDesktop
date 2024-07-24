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
$AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
$appDir = Join-Path -Path $BuildDir -ChildPath $SoftwareName
New-Item -Path $appDir -ItemType Directory -Force | Out-Null
$DestFile = Join-Path -Path $appDir -ChildPath $BlobName
Write-Output "Downloading $BlobName from storage."
$WebClient = New-Object System.Net.WebClient
$WebClient.Headers.Add('x-ms-version', '2017-11-09')
$webClient.Headers.Add("Authorization", "Bearer $AccessToken")
$webClient.DownloadFile("$StorageEndpoint$ContainerName/$BlobName", "$destFile")
Start-Sleep -seconds 10
If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $BlobName"; Exit 1 }
Unblock-File -Path $DestFile
Write-Output "Extracting Contents of Zip File"
Expand-Archive -Path $destFile -DestinationPath "$appDir" -Force
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