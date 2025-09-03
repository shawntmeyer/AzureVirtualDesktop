#region functions
Function Write-Log {
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet("Info", "Warning", "Error")]
        $Category = 'Info',
        [Parameter(Mandatory = $true, Position = 1)]
        $Message
    )

    $Date = get-date
    $Content = "[$Date]`t$Category`t`t$Message`n" 
    Add-Content $Script:Log $content -ErrorAction Stop
    If ($Verbose) {
        Write-Verbose $Content
    }
    Else {
        Switch ($Category) {
            'Info' { Write-Host $content }
            'Error' { Write-Error $Content }
            'Warning' { Write-Warning $Content }
        }
    }
}

function New-Log {

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
$Script:Name = 'Install-VisualC++Redistributables'
New-Log (Join-Path -Path $Env:SystemRoot -ChildPath 'Logs')
$ErrorActionPreference = 'Stop'
Write-Log -category Info -message "Starting '$PSCommandPath'."
#endregion
#region Main
[string]$InstallArguments = "/install /quiet /norestart"

$pathExe = (Get-ChildItem -Path $PSScriptRoot -File -Filter '*.exe').FullName
Write-Log Info -message "Executing '$pathExe $InstallArguments'"
$Installer = Start-Process -FilePath $pathExe -ArgumentList $InstallArguments -Wait -PassThru
If ($($Installer.ExitCode) -eq 0) {
    Write-Log -category Info -message "'Visual C++ Redistributables' installed successfully."
}
Elseif ($($Installer.ExitCode) -eq 3010){
    Write-Log -category Info -message "The Installer exit code is $($Installer.ExitCode). A reboot is required."
}
Else {
    Write-Log -category Error -message "The Installer exit code is $($Installer.ExitCode)"
}
Write-Output "Ending '$PSCommandPath'."
Exit $($Installer.ExitCode)
