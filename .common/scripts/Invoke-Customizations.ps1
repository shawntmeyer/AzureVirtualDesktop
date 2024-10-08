param(
  [string]$APIVersion,
  [string]$Arguments,
  [string]$BlobStorageSuffix,
  [string]$BuildDir,
  [string]$Name,
  [string]$Uri,
  [string]$UserAssignedIdentityClientId
)

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
Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$Name.log" -Force

Write-OutputWithTimeStamp "Starting '$Name' script with the following parameters."
Write-Output ( $PSBoundParameters | Format-Table -AutoSize )
If ($Arguments -eq '') { $Arguments = $null }
If ($Null -eq $BuildDir -or $BuildDir -ne '') {
  $TempDir = Join-Path $BuildDir -ChildPath $Name
} Else {
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
$SourceFileName = ($Uri -Split "/")[-1]
Write-OutputWithTimeStamp "Downloading '$Uri' to '$TempDir'."
$DestFile = Join-Path -Path $TempDir -ChildPath $SourceFileName
$webClient.DownloadFile("$Uri", "$DestFile")
Start-Sleep -Seconds 10
If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $SourceFileName"; Exit 1 }
Write-OutputWithTimeStamp 'Finished downloading'
Set-Location -Path $TempDir
$Ext = [System.IO.Path]::GetExtension($DestFile).ToLower()
switch ($Ext) {
  'exe' {
      If ($Arguments) {
        Write-OutputWithTimeStamp "Executing '`"$DestFile`" $Arguments'"
        Start-Process -FilePath "$DestFile" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
      }
      Else {
        Write-OutputWithTimeStamp "Executing `"$DestFile`""
        Start-Process -FilePath "$DestFile" -NoNewWindow -Wait -PassThru
      }
      $status = Get-WmiObject -Class Win32_Product | Where-Object Name -like "*$($Name)*"
      if ($status) {
        Write-OutputWithTimeStamp $status[0].Name " is installed"
      }
      else {
        Write-OutputWithTimeStamp "'$Name' did not install properly, please check arguments"
      } 
    }
  'msi' {
    If ($Arguments) {
      If ($Arguments -notcontains $SourceFileName) {
        $Arguments = "/i $DestFile $Arguments"
      }
      Write-OutputWithTimeStamp "Executing 'msiexec.exe $Arguments'"
      Start-Process -FilePath msiexec.exe -ArgumentList $Arguments -Wait
    }
    Else {
      Write-OutputWithTimeStamp "Executing 'msiexec.exe /i $DestFile /qn'"
      Start-Process -FilePath msiexec.exe -ArgumentList "/i $DestFile /qn" -Wait
    }
    $status = Get-WmiObject -Class Win32_Product | Where-Object Name -like "*$($Name)*"
    if ($status) {
      Write-OutputWithTimeStamp $status.Name " is installed"
    }
    else {
      Write-OutputWithTimeStamp "'$Name' did not install properly, please check arguments"
    }
  }
  'bat' {
    If ($Arguments) {
      Write-OutputWithTimeStamp "Executing 'cmd.exe `"$DestFile`" $Arguments'"
      Start-Process -FilePath cmd.exe -ArgumentList "`"$DestFile`" $Arguments" -Wait
    }
    Else {
      Write-OutputWithTimeStamp "Executing 'cmd.exe `"$DestFile`"'"
      Start-Process -FilePath cmd.exe -ArgumentList "`"$DestFile`"" -Wait
    }
  }
  'ps1' {
    If ($Arguments) {
      Write-OutputWithTimeStamp "Calling PowerShell Script '$DestFile' with arguments '$Arguments'"
      & $DestFileName $Arguments
    }
    Else {
      Write-OutputWithTimeStamp "Calling PowerShell Script '$DestFile'"
      & $DestFileName
    }
  }
  'zip' {
    $DestinationPath = Join-Path -Path "$TempDir" -ChildPath $([System.IO.Path]::GetFileNameWithoutExtension($SourceFileName))
    Write-OutputWithTimeStamp "Extracting '$DestFile' to '$DestinationPath'."
    Expand-Archive -Path $DestFileName -DestinationPath $DestinationPath -Force
    Write-OutputWithTimeStamp "Finding PowerShell script in root of '$DestinationPath'."
    $PSScript = (Get-ChildItem -Path $DestinationPath -filter '*.ps1').FullName
    If ($PSScript.count -gt 1) { $PSScript = $PSScript[0] }
    If ($Arguments) {
      Write-OutputWithTimeStamp "Calling PowerShell Script '$PSScript' with arguments '$Arguments'"
      & $PSScript $Arguments
    }
    Else {
      Write-OutputWithTimeStamp "Calling PowerShell Script '$PSScript'"         
      & $PSScript
    }
  }
}
If ($null -eq $BuildDir -or $BuildDir -eq '') {Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue}
Stop-Transcript