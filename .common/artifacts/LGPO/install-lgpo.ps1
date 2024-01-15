[CmdletBinding()]
param (
    [Parameter()]
    [Hashtable]$DynParameters
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
        [Parameter(Mandatory=$false, Position=0)]
        [ValidateSet("Info","Warning","Error")]
        $category = 'Info',
        [Parameter(Mandatory=$true, Position=1)]
        $message
    )

    $date = get-date
    $content = "[$date]`t$category`t`t$message`n"
    Write-Verbose "$Script:Name $content" -verbose

    if (! $script:Log) {
        $File = Join-Path $env:TEMP "log.log"
        Write-Error "Log file not found, create new $File"
        $script:Log = $File
    }
    else {
        $File = $script:Log
    }
    Add-Content $File $content -ErrorAction Stop
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
        [Parameter(Mandatory = $true, Position=0)]
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
$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
$LogDir = "$env:SystemRoot\Logs\Configuration"
New-Log $LogDir
$ErrorActionPreference = 'Stop'
Write-Log -category Info -message "Starting '$PSCommandPath'."
#endregion Initialization

#region main
$softwareName = 'LGPO'
$DestFile = "$env:SystemRoot\System32\lgpo.exe"
$azipfiles = Get-ChildItem -Path $PSScriptRoot -filter '*.zip' -recurse
$lgpozip = $azipfiles[0].FullName
Write-Log -category Info -message "Expanding '$lgpozip' to '$PSScriptRoot\temp'."
expand-archive -path "$lgpozip" -DestinationPath "$PSScriptRoot\temp" -force
$algpoexe = Get-ChildItem -Path "$PSScriptRoot\temp" -filter 'lgpo.exe' -recurse
If ($algpoexe.count -gt 0) {
    $lgpoexe=$algpoexe[0].FullName
    Write-Log -category Info -message "Copying '$lgpoexe' to '$env:SystemRoot\system32'."
    Copy-Item -Path $lgpoexe -Destination "$env:SystemRoot\System32" -force
    If (Test-Path $DestFile) {
        Write-Log -category Info -message "'$SoftwareName' installed successfully."
    }
}
Else {
    Write-Log -category Error -Message "'lgpo.exe' not found in downloaded zip."
}
#endregion Main
Write-Log -category Info -message "Ending '$PSCommandPath'."