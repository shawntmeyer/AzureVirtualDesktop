param(
    [string]$APIVersion,
    [string]$AppsToInstall,
    [string]$BlobStorageSuffix,
    [string]$BuildDir,
    [string]$Environment,
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

[array]$AppsToInstall = $AppsToInstall.Replace('\"', '"') | ConvertFrom-Json

If (!(Test-Path -Path "$env:SystemRoot\Logs\ImageBuild")) { New-Item -Path "$env:SystemRoot\Logs\ImageBuild" -ItemType Directory -Force | Out-Null }
$SoftwareName = 'Microsoft-365-Applications'
Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
Write-OutputWithTimeStamp "Starting Script to install '$SoftwareName' with the following parameters:"
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
Write-OutputWithTimeStamp "Finished downloading"
Write-OutputWithTimeStamp "Extracting the Office 365 Deployment Toolkit."
Start-Process -FilePath $destFile -ArgumentList "/extract:`"$appDir\ODT`" /quiet /passive /norestart" -Wait -PassThru | Out-Null
$Setup = (Get-ChildItem -Path "$appDir\ODT" -Filter '*setup*.exe').FullName
Write-OutputWithTimeStamp "Found Office Deployment Tool Setup Executable - '$Setup'."
Write-OutputWithTimeStamp "Dynamically creating $SoftwareName configuration file for setup."
$ConfigFile = Join-Path -Path $appDir -ChildPath 'office365x64.xml'
Set-Content -Path $ConfigFile -Value '<Configuration>'
Switch ($Environment) {
    "USSec" {
        Add-Content -Path $ConfigFile -Value '  <Add AllowCdnFallback="TRUE" SourcePath="https://officexo.azurefd.microsoft.scloud/prsstelecontainer/55336b82-a18d-4dd6-b5f6-9e5095c314a6/" Channel="MonthlyEnterprise" OfficeClientEdition="64">'
    }
    "USNat" { 
        Add-Content -Path $ConfigFile -Value '  <Add AllowCdnFallback="TRUE" SourcePath="https://officexo.azurefd.eaglex.ic.gov/prsstelecontainer/55336b82-a18d-4dd6-b5f6-9e5095c314a6/" Channel="MonthlyEnterprise" OfficeClientEdition="64">'
    }
    Default {
        Add-Content -Path $ConfigFile -Value '  <Add OfficeClientEdition="64" Channel="MonthlyEnterprise">'
    }
}        
Add-Content -Path $ConfigFile -Value '    <Product ID="O365ProPlusRetail">'
Add-Content -Path $ConfigFile -Value '      <Language ID="en-us" />'
Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Groove" />'
Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="OneDrive" />'
Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Teams" />'
if ($AppsToInstall -notcontains 'Access') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Access" />'
}
if ($AppsToInstall -notcontains 'Excel') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Excel" />'
}
if ($AppsToInstall -notcontains 'OneNote') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="OneNote" />'
}
if ($AppsToInstall -notcontains 'Outlook') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Outlook" />'
}
if ($AppsToInstall -notcontains 'PowerPoint') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="PowerPoint" />'
}
if ($AppsToInstall -notcontains 'Publisher') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Publisher" />'
}
if ($AppsToInstall -notcontains 'Lync') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Lync" />'
}
if ($AppsToInstall -notcontains 'Word') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Word" />'
}
Add-Content -Path $ConfigFile -Value '    </Product>'
if ($AppsToInstall -contains 'Project') {
    Add-Content -Path $ConfigFile -Value '    <Product ID="ProjectProRetail">'
    Add-Content -Path $ConfigFile -Value '      <Language ID="en-us" /></Product>'
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Groove" />'
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Lync" />'
    Add-Content -Path $ConfigFile -Value '    </Product>'
}
if ($AppsToInstall -contains 'Visio') {
    Add-Content -Path $ConfigFile -Value '    <Product ID="VisioProRetail">'
    Add-Content -Path $ConfigFile -Value '      <Language ID="en-us" /></Product>'
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Groove" />'
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Lync" />'
    Add-Content -Path $ConfigFile -Value '    </Product>'
}
Add-Content -Path $ConfigFile -Value '  </Add>'
Add-Content -Path $ConfigFile -Value '  <Property Name="SharedComputerLicensing" Value="1" />'
Add-Content -Path $ConfigFile -Value '  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />'
Add-Content -Path $ConfigFile -Value '  <Updates Enabled="FALSE" />'
Add-Content -Path $ConfigFile -Value '  <Display Level="None" AcceptEULA="TRUE" />'
Add-Content -Path $ConfigFile -Value '</Configuration>'
Write-OutputWithTimeStamp "Config File Content:"
Write-OutputWithTimeStamp "---------------------------------------------------------------------------------------------------------"
$ConfigFileContent = Get-Content -Path $ConfigFile
Write-Output $ConfigFileContent
Write-OutputWithTimeStamp "---------------------------------------------------------------------------------------------------------"
Write-OutputWithTimeStamp "Starting setup process."
$Install = Start-Process -FilePath $Setup -ArgumentList "/configure `"$ConfigFile`"" -Wait -PassThru -ErrorAction "Stop"
If ($($Install.ExitCode) -eq 0) {
    Write-OutputWithTimeStamp "'$SoftwareName' installed successfully."
}
Else {
    Write-Error "'$SoftwareName' install exit code is $($Install.ExitCode)"
}
Stop-Transcript