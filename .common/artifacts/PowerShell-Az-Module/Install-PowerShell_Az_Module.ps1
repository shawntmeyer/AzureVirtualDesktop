Param
(
    [Parameter(Mandatory = $false)]
    [Hashtable]$DynParameters
)

#region functions
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
$SoftwareName = 'PowerShell Az Modules'
$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
New-Log "C:\Windows\Logs\Software"
$ErrorActionPreference = 'Stop'
Write-Log -category Info -message "Starting '$PSCommandPath'."
#endregion
#region Main
$pathMSI = (Get-ChildItem -Path $PSScriptRoot -File -Filter '*.msi').FullName
[string]$MSIExecArgs = "/i $pathMSI /quiet /qn /norestart /passive"

Write-Log -category Info -message "Executing 'msiexec.exe $MSIExecArgs'"
$Installer = Start-Process -FilePath 'msiexec.exe' -ArgumentList $MSIExecArgs -Wait -PassThru
If ($($Installer.ExitCode) -eq 0) {
    Write-Log -category Info -message "'$SoftwareName' installed successfully."
}
Elseif ($($Installer.ExitCode) -eq 3010){
    Write-Log -category Info -message "The Installer exit code is $($Installer.ExitCode). A reboot is required."
}
Else {
    Write-Log -category Error -message "The Installer exit code is $($Installer.ExitCode)"
}
Write-Output "Ending '$PSCommandPath'."
Exit $($Installer.ExitCode)
