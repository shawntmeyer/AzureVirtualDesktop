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
  Write-Output "Downloading '$BlobName' to '$InstallDir'."
  $WebClient = New-Object System.Net.WebClient
  $WebClient.Headers.Add('x-ms-version', '2017-11-09')
  $webClient.Headers.Add("Authorization", "Bearer $AccessToken")
  $webClient.DownloadFile("$StorageEndpoint$ContainerName/$BlobName", "$InstallDir\$BlobName")
  Start-Sleep -Seconds 10
  If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $BlobName"; Exit 1 }
  Write-Output 'Finished downloading'
  Set-Location -Path $InstallDir
  if($Blobname -like '*.exe') {
    If ($Arguments) {
      Start-Process -FilePath "$InstallDir\$Blobname" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
    } Else {
      Start-Process -FilePath "$InstallDir\$Blobname" -NoNewWindow -Wait -PassThru
    }
    $status = Get-WmiObject -Class Win32_Product | Where-Object Name -like "*$($installer)*"
    if($status) {
      Write-Output $status.Name " is installed"
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
      Write-Output $status.Name " is installed"
    } else {
      Write-Output "$Installer did not install properly, please check arguments"
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
    $destinationPath = Join-Path -Path "$InstallDir" -ChildPath $([System.IO.Path]::GetFileNameWithoutExtension($Blobname))
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