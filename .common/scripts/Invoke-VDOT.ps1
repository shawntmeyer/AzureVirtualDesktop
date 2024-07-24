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
$AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
$DestFile = Join-Path -Path $BuildDir -ChildPath $BlobName
$WebClient = New-Object System.Net.WebClient
$WebClient.Headers.Add('x-ms-version', '2017-11-09')
$webClient.Headers.Add("Authorization", "Bearer $AccessToken")
$webClient.DownloadFile("$StorageEndpoint$ContainerName/$BlobName", "$DestFile")
Start-Sleep -seconds 10
If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $BlobName"; Exit 1 }
Unblock-File -Path $DestFile
$VDOTDir = Join-Path -Path $BuildDir -ChildPath 'VDOT'
Expand-Archive -LiteralPath $DestFile -DestinationPath $VDOTDir -Force
$ScriptPath = (Get-ChildItem -Path $VDOTDir -Recurse | Where-Object { $_.Name -eq "Windows_VDOT.ps1" }).FullName
$ScriptContents = Get-Content -Path $ScriptPath
$ScriptUpdate = $ScriptContents.Replace("Set-NetAdapterAdvancedProperty", "#Set-NetAdapterAdvancedProperty")
$ScriptUpdate | Set-Content -Path $ScriptPath
& $ScriptPath -Optimizations @("AppxPackages", "Autologgers", "DefaultUserSettings", "LGPO", "NetworkOptimizations", "ScheduledTasks", "Services", "WindowsMediaPlayer") -AdvancedOptimizations @("Edge", "RemoveLegacyIE") -AcceptEULA
Write-Output "Optimized the operating system using the Virtual Desktop Optimization Tool"
Stop-Transcript