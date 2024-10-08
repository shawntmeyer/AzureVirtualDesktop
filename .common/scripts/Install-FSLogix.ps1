param(
    [string]$APIVersion,
    [string]$BlobStorageSuffix,
    [string]$BuildDir,
    [string]$UserAssignedIdentityClientId,
    [string]$Uri
)

$ErrorActionPreference = "Stop"

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

$SoftwareName = 'FSLogix'
Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
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
Start-Sleep -seconds 10
If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $SourceFileName"; Exit 1 }
Unblock-File -Path $DestFile
Write-OutputWithTimeStamp "Extracting Contents of Zip File"
Expand-Archive -Path $destFile -DestinationPath "$appDir" -Force
$Installer = (Get-ChildItem -Path $appDir -File -Recurse -Filter 'FSLogixAppsSetup.exe' | Where-Object { $_.FullName -like '*x64*' }).FullName
Write-OutputWithTimeStamp "Installation file found: [$Installer], executing installation."
$Install = Start-Process -FilePath $Installer -ArgumentList "/install /quiet /norestart" -Wait -PassThru
If ($($Install.ExitCode) -eq 0) {
    Write-OutputWithTimeStamp "'Microsoft FSLogix Apps' installed successfully."
}
Else {
    Write-Error "The Install exit code is $($Install.ExitCode)"
}
Write-OutputWithTimeStamp "Copying the FSLogix ADMX and ADML files to the PolicyDefinitions folders."
Get-ChildItem -Path $appDir -File -Recurse -Filter '*.admx' | ForEach-Object { Write-OutputWithTimeStamp "Copying $($_.Name)"; Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\" -Force }
Get-ChildItem -Path $appDir -File -Recurse -Filter '*.adml' | ForEach-Object { Write-OutputWithTimeStamp "Copying $($_.Name)"; Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\en-us\" -Force }
Write-OutputWithTimeStamp "Installation complete."
Stop-Transcript