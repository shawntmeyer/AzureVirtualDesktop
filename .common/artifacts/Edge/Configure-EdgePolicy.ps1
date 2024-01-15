[CmdletBinding(SupportsShouldProcess = $true)]
param (

    [Parameter(Mandatory = $false)]
    [Hashtable] $DynParameters
)

[string]$LogDir = "$env:SystemRoot\Logs\Configuration"
[string]$ScriptName = "Configure-EdgePolicy"
[string]$Log = Join-Path -Path $LogDir -ChildPath "$ScriptName.log"
[string]$tempDir = Join-Path -Path $env:Temp -ChildPath $ScriptName

#region Functions

Function Update-LocalGPOTextFile {
    [CmdletBinding(DefaultParameterSetName = 'Set')]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Delete')]
        [Parameter(Mandatory = $true, ParameterSetName = 'DeleteAllValues')]
        [ValidateSet('Computer', 'User')]
        [string]$scope,
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Delete')]
        [Parameter(Mandatory = $true, ParameterSetName = 'DeleteAllValues')]
        [string]$RegistryKeyPath,
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Delete')]
        [Parameter(Mandatory = $true, ParameterSetName = 'DeleteAllValues')]
        [string]$RegistryValue,
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [AllowEmptyString()]
        [string]$RegistryData,
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [ValidateSet('DWORD', 'String')]
        [string]$RegistryType,
        [Parameter(Mandatory = $false, ParameterSetName = 'Delete')]
        [switch]$Delete,
        [Parameter(Mandatory = $false, ParameterSetName = 'DeleteAllValues')]
        [switch]$DeleteAllValues,
        [string]$outputDir = "$TempDir\LGPO",
        [string]$outfileprefix = $appName
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        # Convert $RegistryType to UpperCase to prevent LGPO errors.
        $ValueType = $RegistryType.ToUpper()
        # Change String type to SZ for text file
        If ($ValueType -eq 'STRING') { $ValueType = 'SZ' }
        # Replace any incorrect registry entries for the format needed by text file.
        $modified = $false
        $SearchStrings = 'HKLM:\', 'HKCU:\', 'HKEY_CURRENT_USER:\', 'HKEY_LOCAL_MACHINE:\'
        ForEach ($String in $SearchStrings) {
            If ($RegistryKeyPath.StartsWith("$String") -and $modified -ne $true) {
                $index = $String.Length
                $RegistryKeyPath = $RegistryKeyPath.Substring($index, $RegistryKeyPath.Length - $index)
                $modified = $true
            }
        }
        
        #Create the output file if needed.
        $Outfile = "$OutputDir\$Outfileprefix-$Scope.txt"
        If (-not (Test-Path -LiteralPath $Outfile)) {
            If (-not (Test-Path -LiteralPath $OutputDir -PathType 'Container')) {
                Try {
                    $null = New-Item -Path $OutputDir -Type 'Directory' -Force -ErrorAction 'Stop'
                }
                Catch {}
            }
            $null = New-Item -Path $outputdir -Name "$OutFilePrefix-$Scope.txt" -ItemType File -ErrorAction Stop
        }

        Write-Log -message "${CmdletName}: Adding registry information to '$outfile' for LGPO.exe"
        # Update file with information
        Add-Content -Path $Outfile -Value $Scope
        Add-Content -Path $Outfile -Value $RegistryKeyPath
        Add-Content -Path $Outfile -Value $RegistryValue
        If ($Delete) {
            Add-Content -Path $Outfile -Value 'DELETE'
        }
        ElseIf ($DeleteAllValues) {
            Add-Content -Path $Outfile -Value 'DELETEALLVALUES'
        }
        Else {
            Add-Content -Path $Outfile -Value "$($ValueType):$RegistryData"
        }
        Add-Content -Path $Outfile -Value ""
    }
    End {        
    }
}

Function Invoke-LGPO {
    [CmdletBinding()]
    Param (
        [string]$InputDir = "$TempDir\LGPO",
        [string]$SearchTerm
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Write-Log -category Info -message "${CmdletName}: Gathering Registry text files for LGPO from '$InputDir'"
        If ($SearchTerm) {
            $InputFiles = Get-ChildItem -Path $InputDir -Filter "$SearchTerm*.txt"
        }
        Else {
            $InputFiles = Get-ChildItem -Path $InputDir -Filter '*.txt'
        }
        ForEach ($RegistryFile in $inputFiles) {
            $TxtFilePath = $RegistryFile.FullName
            Write-Log -message "${CmdletName}: Now applying settings from '$txtFilePath' to Local Group Policy via LGPO.exe."
            $lgporesult = Start-Process -FilePath 'lgpo.exe' -ArgumentList "/t `"$TxtFilePath`"" -Wait -PassThru
            Write-Log -message "${CmdletName}: LGPO exitcode: '$($lgporesult.exitcode)'"
        }
    }
    End {
    }
}

function Write-Log {

    <#
    .SYNOPSIS
    Creates a log file and stores logs based on categories with tab seperation

    .PARAMETER category
    Category to put into the trace

    .PARAMETER message
    Message to be logged

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
New-Log "C:\Windows\Logs\Configuration"
$ErrorActionPreference = 'Stop'
Write-Log -category Info -message "Starting '$PSCommandPath'."
#endregion

Write-Log -category Info -message "Running Script to Configure Microsoft Edge Policies."

$EdgeTemplatesCab = (Get-ChildItem -Path $PSScriptRoot -Filter '*.cab').FullName

New-Item -Path "$PSScriptRoot\$Script:Name" -ItemType Directory -Force | out-null
Write-Log -category Info -message "Expanding `"$EdgeTemplatesCab`" into `"$PSScriptRoot\$Script:Name`"."
& cmd /c extrac32 /Y /E $EdgeTemplatesCab /L "$PSScriptRoot\$Script:Name"
$EdgeTemplatesZip = Get-ChildItem -Path "$PSScriptRoot\$Script:Name" -Filter '*.zip' -File -Recurse
$EdgeTemplatesZip = $EdgeTemplatesZip[0].FullName
Expand-Archive -Path $EdgeTemplatesZip -DestinationPath "$PSScriptRoot\$Script:Name" -force
Write-Log -category Info -message "Copy ADMX and ADML files to PolicyDefinition Folders."

$null = Get-ChildItem -Path "$PSScriptRoot\$Script:Name" -File -Recurse -Filter '*.admx' | ForEach-Object { Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\" -Force }
$null = Get-ChildItem -Path "$PSScriptRoot\$Script:Name" -Directory -Recurse | Where-Object {$_.Name -eq 'en-us'} | Get-ChildItem -File -recurse -filter '*.adml' | ForEach-Object { Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\en-us\" -Force }

If (Test-Path -Path "$env:SystemRoot\System32\Lgpo.exe") {

    $appName = 'Edge'

    Write-Log -category Info -message "Now Configuring Edge Group Policy."
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'HideFirstRunExperience' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'NonRemovableProfileEnabled' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'ProxySettings' -Delete -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'AutomaticHttpsDefault' -RegistryData 0 -RegistryType DWORD -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'DownloadRestrictions' -RegistryType 'DWord' -RegistryData 4 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge\SmartScreenAllowListDomains' -RegistryValue '*' -DeleteAllValues -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge\SmartScreenAllowListDomains' -RegistryValue '1' -RegistryType 'STRING' -RegistryData 'portal.azure.com' -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge\SmartScreenAllowListDomains' -RegistryValue '2' -RegistryType 'STRING' -RegistryData 'core.windows.net' -outfileprefix $appName -Verbose
    Invoke-LGPO -Verbose
}
Else {
    Write-Log -category Error -message "Unable to configure local policy with lgpo tool because it was not found."
    Exit 2
}