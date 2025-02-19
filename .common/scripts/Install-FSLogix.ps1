param(
    [string]$APIVersion,
    [string]$BlobStorageSuffix,
    [string]$BuildDir='',
    [string]$UserAssignedIdentityClientId,
    [string]$Uri=''
)
function Write-OutputWithTimeStamp {
    param(
        [string]$Message
    )    
    $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss'
    $Entry = '[' + $Timestamp + '] ' + $Message
    Write-Output $Entry
}

$ErrorActionPreference = "Stop"
$Name = 'FSLogix'
Start-Transcript -Path "$env:SystemRoot\Logs\Install-$Name.log" -Force
Write-OutputWithTimeStamp "Starting '$SoftwareName' install script with following Parameters:"
Write-Output ( $PSBoundParameters | Format-Table -AutoSize )

If ($Uri -eq '') {
    $Uri = 'https://aka.ms/fslogix_download'
}
If ($BuildDir -ne '') {
    $TempDir = Join-Path $BuildDir -ChildPath $Name
}
Else {
    $TempDir = Join-Path $Env:TEMP -ChildPath $Name
}
New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
$WebClient = New-Object System.Net.WebClient
If ($Uri -match $BlobStorageSuffix -and $UserAssignedIdentityClientId -ne '') {
    $StorageEndpoint = ($Uri -split "://")[0] + "://" + ($Uri -split "/")[2] + "/"
    $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
    $AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
    $WebClient.Headers.Add('x-ms-version', '2017-11-09')
    $webClient.Headers.Add("Authorization", "Bearer $AccessToken")
}
$DestFile = Join-Path -Path $TempDir -ChildPath 'FSLogix.zip'
Write-OutputWithTimeStamp "Downloading 'FSLogix.zip' from '$uri' to '$DestFile'."
$webClient.DownloadFile("$Uri", "$DestFile")
Start-Sleep -seconds 10
If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $SourceFileName"; Exit 1 }
Unblock-File -Path $DestFile
Write-OutputWithTimeStamp "Extracting Contents of Zip File"
Expand-Archive -Path $destFile -DestinationPath $TempDir -Force
$Installer = (Get-ChildItem -Path $TempDir -File -Recurse -Filter 'FSLogixAppsSetup.exe' | Where-Object { $_.FullName -like '*x64*' }).FullName
Write-OutputWithTimeStamp "Installation file found: [$Installer], executing installation."
$Install = Start-Process -FilePath $Installer -ArgumentList "/install /quiet /norestart" -Wait -PassThru
If ($($Install.ExitCode) -eq 0) {
    Write-OutputWithTimeStamp "'Microsoft FSLogix Apps' installed successfully."
}
Else {
    Write-Error "The Install exit code is $($Install.ExitCode)"
}
Write-OutputWithTimeStamp "Copying the FSLogix ADMX and ADML files to the PolicyDefinitions folders."
Get-ChildItem -Path $TempDir -File -Recurse -Filter '*.admx' | ForEach-Object { Write-OutputWithTimeStamp "Copying $($_.Name)"; Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\" -Force }
Get-ChildItem -Path $TempDir -File -Recurse -Filter '*.adml' | ForEach-Object { Write-OutputWithTimeStamp "Copying $($_.Name)"; Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\en-us\" -Force }
If ((Split-Path $TempDir -Parent) -eq $Env:Temp) { Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue }
Write-OutputWithTimeStamp "Installation complete."
Stop-Transcript