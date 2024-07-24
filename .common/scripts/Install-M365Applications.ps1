param(
    [string]$APIVersion,
    [string]$BuildDir,
    [string]$Environment,
    [string]$InstallAccess,
    [string]$InstallExcel,
    [string]$InstallOutlook,
    [string]$InstallProject,
    [string]$InstallPublisher,
    [string]$InstallSkypeForBusiness,
    [string]$InstallVisio,
    [string]$InstallWord,
    [string]$InstallOneNote,
    [string]$InstallPowerPoint,
    [string]$UserAssignedIdentityClientId,
    [string]$ContainerName,
    [string]$StorageEndpoint,
    [string]$BlobName
)

function Write-OutputWithTimeStamp {
    param(
        [parameter(ValueFromPipeline=$True, Mandatory=$True, Position=0)]
        [string]$Message
    )    
    $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
    $Entry = '[' + $Timestamp + ']' + $Message
    Write-Output $Entry
}

$ErrorActionPreference = "Stop"
$SoftwareName = 'Microsoft-365-Applications'
Start-Transcript -Path "$env:SystemRoot\Logs\ImageBuild\$SoftwareName.log" -Force
Write-OutputWithTimeStamp "Starting Script to install '$SoftwareName' with the following parameters:"
Write-Output $PSBoundParameters
$TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
$AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
$sku = (Get-ComputerInfo).OsName
$appDir = Join-Path -Path $BuildDir -ChildPath $SoftwareName
New-Item -Path $appDir -ItemType Directory -Force | Out-Null  
$DestFile = Join-Path -Path $appDir -ChildPath $BlobName
$WebClient = New-Object System.Net.WebClient
$WebClient.Headers.Add('x-ms-version', '2017-11-09')
$webClient.Headers.Add("Authorization", "Bearer $AccessToken")
$webClient.DownloadFile("$StorageEndpoint$ContainerName/$BlobName", "$DestFile")
Start-Sleep -seconds 5
If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $BlobName"; Exit 1 }
Start-Process -FilePath $destFile -ArgumentList "/extract:`"$appDir\ODT`" /quiet /passive /norestart" -Wait -PassThru | Out-Null
Write-OutputWithTimeStamp "Downloaded & extracted the Office 365 Deployment Toolkit"
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
if ($InstallAccess -ne 'True') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Access" />'
}
if ($InstallExcel -ne 'True') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Excel" />'
}
if ($InstallOneNote -ne 'True') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="OneNote" />'
}
if ($InstallOutlook -ne 'True') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Outlook" />'
}
if ($InstallPowerPoint -ne 'True') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="PowerPoint" />'
}
if ($InstallPublisher -ne 'True') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Publisher" />'
}
if ($InstallSkypeForBusiness -ne 'True') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Lync" />'
}
if ($InstallWord -ne 'True') {
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Word" />'
}
Add-Content -Path $ConfigFile -Value '    </Product>'
if ($InstallProject -eq 'True') {
    Add-Content -Path $ConfigFile -Value '    <Product ID="ProjectProRetail">'
    Add-Content -Path $ConfigFile -Value '      <Language ID="en-us" /></Product>'
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Groove" />'
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Lync" />'
    Add-Content -Path $ConfigFile -Value '    </Product>'
}
if ($InstallVisio -eq 'True') {
    Add-Content -Path $ConfigFile -Value '    <Product ID="VisioProRetail">'
    Add-Content -Path $ConfigFile -Value '      <Language ID="en-us" /></Product>'
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Groove" />'
    Add-Content -Path $ConfigFile -Value '      <ExcludeApp ID="Lync" />'
    Add-Content -Path $ConfigFile -Value '    </Product>'
}
Add-Content -Path $ConfigFile -Value '  </Add>'
if (($Sku).Contains("multi") -eq "true") {
    Add-Content -Path $ConfigFile -Value '  <Property Name="SharedComputerLicensing" Value="1" />'
}
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