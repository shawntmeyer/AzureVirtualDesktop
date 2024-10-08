param(
    [string]$APIVersion,
    [string]$BlobStorageSuffix,
    [string]$BuildDir,
    [string]$Uri,
    [string]$UserAssignedIdentityClientId
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

$SoftwareName = 'VDOT'
If (!(Test-Path -Path "$env:SystemRoot\Logs\ImageBuild")) { New-Item -Path "$env:SystemRoot\Logs\ImageBuild" -ItemType Directory -Force | Out-Null }
Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
Write-OutputWithTimeStamp "Starting '$SoftwareName' script with the following parameters:"
Write-Output ( $PSBoundParameters | Format-Table -AutoSize )

$WebClient = New-Object System.Net.WebClient
If ($Uri -match $BlobStorageSuffix -and $UserAssignedIdentityClientId -ne '') {
    $StorageEndpoint = ($Uri -split "://")[0] + "://" + ($Uri -split "/")[2] + "/"
    $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
    $AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
    $WebClient.Headers.Add('x-ms-version', '2017-11-09')
    $webClient.Headers.Add("Authorization", "Bearer $AccessToken")
}
$SourceFileName = ($Uri -Split "/")[-1]
$DestFile = Join-Path -Path $BuildDir -ChildPath $SourceFileName
Write-OutputWithTimeStamp "Downloading '$Uri' to '$DestFile'."
$webClient.DownloadFile("$Uri", "$DestFile")
Start-Sleep -seconds 5
If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $Uri"; Exit 1 }
Unblock-File -Path $DestFile
$VDOTDir = Join-Path -Path $BuildDir -ChildPath $SoftwareName
Expand-Archive -LiteralPath $DestFile -DestinationPath $VDOTDir -Force
$ScriptPath = (Get-ChildItem -Path $VDOTDir -Recurse | Where-Object { $_.Name -eq "Windows_VDOT.ps1" }).FullName
$ScriptContents = Get-Content -Path $ScriptPath
$ScriptUpdate = $ScriptContents.Replace("Set-NetAdapterAdvancedProperty", "#Set-NetAdapterAdvancedProperty")
$ScriptUpdate | Set-Content -Path $ScriptPath
& $ScriptPath -Optimizations @("Autologgers", "DefaultUserSettings", "DiskCleanup", "LocalPolicy", "NetworkOptimizations", "ScheduledTasks", "Services", "WindowsMediaPlayer") -AdvancedOptimizations @("Edge", "RemoveLegacyIE") -AcceptEULA
Write-OutputWithTimeStamp "Optimized the operating system using the Virtual Desktop Optimization Tool"
Stop-Transcript