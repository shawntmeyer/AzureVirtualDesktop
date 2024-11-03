<#      
    .DESCRIPTION
    Main script to perform customizations via the Azure VM Image Builder Service. This script is used to download and execute customizers on the VM image being built and is significantly
    faster than using individual customizers scripts within the image template because the VM directly performs the download versus the Azure Image Builder service performing the download and
    then sending the download to the VM. This script is used in the 'Customize' phase of the image template.

    .PARAMETER APIVersion
    The API version to use to get an access token for the storage account(s) via the VM Instance Metadata Service. Default is '2018-02-01'.

    .PARAMETER BlobStorageSuffix
    The suffix of the blob storage account of the azure environment where you are building the image. Default is 'core.windows.net'.  For Azure US Government, use 'core.usgovcloudapi.net'.
    
    .PARAMETER Customizers
    An array of customizers to execute. Each customizer is a hashtable with the following keys:
    - Name: The name of the customizer. (required)
    - Uri: The URI of the customizer. (required)
    - Arguments: The arguments to pass to the customizer. (optional)

    .PARAMETER UserAssignedIdentityClientId
    The client ID of the user assigned identity to use to get an access token for the storage account(s) via the VM Instance Metadata Service.

    .EXAMPLE
    $Customizers = @(
        @{
            Name = 'Customizer1'
            Uri = 'https://myblobstorage.blob.core.windows.net/mycontainer/Customizer1.ps1'
            Arguments = '-arg1 value1 -arg2 value2'
        },
        @{
            Name = 'Customizer2'
            Uri = 'https://myblobstorage.blob.core.windows.net/mycontainer/Customizer2.ps1'
        }
    )
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $APIVersion = '2018-02-01',
    [Parameter(Mandatory = $false)]
    [string] $BlobStorageSuffix,
    [Parameter(Mandatory = $false)]
    [array] $Customizers = @(),
    [Parameter(Mandatory = $false)]
    [string] $UserAssignedIdentityClientId
)

#region Functions

function Write-Log {

    <#
    .SYNOPSIS
    Creates a log file and stores logs based on categories with tab seperation

    .PARAMETER category
    Category to put into the trace

    .PARAMETER message
    Message to be loged

    .EXAMPLE
    Log 'Info' 'Message'

    #>

    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet("Info", "Warning", "Error")]
        $category = 'Info',
        [Parameter(Mandatory = $true, Position = 1)]
        $message
    )

    $date = get-date
    $content = "[$date]`t$category`t`t$message`n" 
    Add-Content $Script:Log $content -ErrorAction Stop
}

function New-Log {
    <#
    .SYNOPSIS
    Sets default log file and stores in a script accessible variable $script:Log
    Log File name "packageExecution_$date.log"

    .PARAMETER Path
    Path to the log file

    .EXAMPLE
    New-Log c:\Windows\Logs
    Create a new log file in c:\Windows\Logs
    #>

    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Path
    )

    # Create central log file with given date

    $date = Get-Date -UFormat "%Y-%m-%d %H-%M-%S"
    Set-Variable logFile -Scope Script
    $script:logFile = "$Script:Name-$date.log"

    if ((Test-Path $path ) -eq $false) {
        $null = New-Item -Path $path -type directory
    }

    $script:Log = Join-Path $path $logfile

    Add-Content $script:Log "Date`t`t`tCategory`t`tDetails"
}

#endregion Functions

#region Initialization
$ErrorActionPreference = 'Stop'
$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
New-Log "$env:SystemRoot\Logs"
Write-Log -category Info -message "Starting '$PSCommandPath'."
Write-Log -category Info -message "Current working dir: $((Get-Location).Path)"

If ($Customizers) {   
    ForEach ($Customizer in $Customizers) {
        $Name = $Customizer.Name
        $Uri = $Customizer.Uri
        $Arguments = $Customizer.Arguments
        Write-Log -category Info -message "Processing '$Name' customizer."
        $TempDir = Join-Path $Env:TEMP -ChildPath $Name
        New-Item -Path $TempDir -ItemType Directory -Force | Out-Null  
        $WebClient = New-Object System.Net.WebClient
        If ($Uri -match $BlobStorageSuffix -and $UserAssignedIdentityClientId -ne '') {
            $StorageEndpoint = ($Uri -split "://")[0] + "://" + ($Uri -split "/")[2] + "/"
            $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=$APIVersion&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
            $AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
            $WebClient.Headers.Add('x-ms-version', '2017-11-09')
            $webClient.Headers.Add("Authorization", "Bearer $AccessToken")
        }
        Write-Log -category Info -message "Downloading '$Uri' to '$TempDir'."
        $SourceFileName = ($Uri -Split "/")[-1]
        $DestFile = Join-Path -Path $TempDir -ChildPath $SourceFileName
        $WebClient.DownloadFile("$Uri", "$DestFile")
        Start-Sleep -Seconds 5
        $WebClient = $null
        If (!(Test-Path -Path $DestFile)) { Write-Error "Failed to download $SourceFileName"; Exit 1 }
        Write-Log -category Info -message 'Finished downloading'
        $Extension = [System.IO.Path]::GetExtension($DestFile).ToLower()
        switch ($Extension) {
            'exe' {
                If ($Arguments) {
                    Write-Log -category Info -message "Executing '`"$DestFile`" $Arguments'"
                    Start-Process -FilePath "$DestFile" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
                }
                Else {
                    Write-Log -category Info -message "Executing `"$DestFile`""
                    Start-Process -FilePath "$DestFile" -NoNewWindow -Wait -PassThru
                }
                $status = Get-WmiObject -Class Win32_Product | Where-Object Name -like "*$($Name)*"
                if ($status) {
                    Write-Log -category Info -message "'$($status[0].Name)'  is installed"
                }
                else {
                    Write-Log -category Info -message "'$Name' did not install properly, please check arguments"
                }                 
            }
            'msi' {
                If ($Arguments) {
                    If ($Arguments -notcontains $SourceFileName) {
                        $Arguments = "/i $DestFile $Arguments"
                    }
                    Write-Log -category Info -message "Executing 'msiexec.exe $Arguments'"
                    Start-Process -FilePath msiexec.exe -ArgumentList $Arguments -Wait
                }
                Else {
                    Write-Log -category Info -message "Executing 'msiexec.exe /i $DestFile /qn'"
                    Start-Process -FilePath msiexec.exe -ArgumentList "/i $DestFile /qn" -Wait
                }
                $status = Get-WmiObject -Class Win32_Product | Where-Object Name -like "*$($Name)*"
                if ($status) {
                    Write-Log -category Info -message "'$($status[0].Name)' is installed"
                }
                else {
                    Write-Log -category Info -message "'$Name' did not install properly, please check arguments"
                }
            }
            'bat' {
                If ($Arguments) {
                    Write-Log -category Info -message "Executing 'cmd.exe `"$DestFile`" $Arguments'"
                    Start-Process -FilePath cmd.exe -ArgumentList "`"$DestFile`" $Arguments" -Wait
                }
                Else {
                    Write-Log -category Info -message "Executing 'cmd.exe `"$DestFile`"'"
                    Start-Process -FilePath cmd.exe -ArgumentList "`"$DestFile`"" -Wait
                }
            }
            'ps1' {
                If ($Arguments) {
                    Write-Log -category Info -message "Calling PowerShell Script '$DestFile' with arguments '$Arguments'"
                    & $DestFileName $Arguments
                }
                Else {
                    Write-Log -category Info -message "Calling PowerShell Script '$DestFile'"
                    & $DestFileName
                }
            }
            'zip' {
                $DestinationPath = Join-Path -Path "$TempDir" -ChildPath $([System.IO.Path]::GetFileNameWithoutExtension($SourceFileName))
                Write-Log -category Info -message "Extracting '$DestFile' to '$DestinationPath'."
                Expand-Archive -Path $DestFileName -DestinationPath $DestinationPath -Force
                Write-Log -category Info -message "Finding PowerShell script in root of '$DestinationPath'."
                $PSScript = (Get-ChildItem -Path $DestinationPath -filter '*.ps1').FullName
                If ($PSScript) {
                    If ($PSScript.count -gt 1) { $PSScript = $PSScript[0] }
                    If ($Arguments) {
                        Write-Log -category Info -message "Calling PowerShell Script '$PSScript' with arguments '$Arguments'"
                        & $PSScript $Arguments
                    }
                    Else {
                        Write-Log -category Info -message "Calling PowerShell Script '$PSScript'"         
                        & $PSScript
                    }
                }
            }
        }
    }
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Log -category Info -message "Ending '$PSCommandPath'."