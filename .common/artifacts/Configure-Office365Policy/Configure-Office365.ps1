[CmdletBinding(SupportsShouldProcess = $true)]
param (

    [Parameter(Mandatory = $false)]
    [boolean]$DisableUpdates,

    [ValidateSet("Not Configured", "3 days", "1 week", "2 weeks", "1 month", "3 months", "6 months", "12 months", "24 months", "36 months", "60 months", "All")]
    [string]$EmailCacheTime = "1 month",

    # Outlook Calendar Sync Mode, Microsoft Recommendation is Primary Calendar Only. See https://support.microsoft.com/en-us/help/2768656/outlook-performance-issues-when-there-are-too-many-items-or-folders-in
    [ValidateSet("Not Configured", "Inactive", "Primary Calendar Only", "All Calendar Folders")]
    [string]$CalendarSync = "Primary Calendar Only",

    # Outlook Calendar Sync Months, Microsoft Recommendation is 1 Month. See https://support.microsoft.com/en-us/help/2768656/outlook-performance-issues-when-there-are-too-many-items-or-folders-in
    [ValidateSet("Not Configured", "1", "3", "6", "12")]
    [string]$CalendarSyncMonths = "1"
)

[string]$AppName = 'Office365'
[string]$LogDir = "$env:SystemRoot\Logs\Configuration"
[string]$ScriptName = "Configure-Office365Policy"
[string]$Log = Join-Path -Path $LogDir -ChildPath "$ScriptName.log"
[string]$TempDir = Join-Path -Path $env:Temp -ChildPath $ScriptName
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
        [string]$outfileprefix = $AppName
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
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet("Info", "Warning", "Error")]
        $category = 'Info',
        [Parameter(Mandatory = $true, Position = 1)]
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
$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
New-Log "C:\Windows\Logs\Configuration"
$ErrorActionPreference = 'Stop'
Write-Log -category Info -message "Starting '$PSCommandPath'."
#endregion

Write-Log -category Info -message "Running Script to Configure Microsoft Office 365 Policies and registry settings."

$O365TemplatesExe = (Get-ChildItem -Path $PSScriptRoot -Filter '*.exe').FullName
$DirTemplates = Join-Path -Path $TempDir -ChildPath 'Office365Templates'
If (-not (Test-Path -Path $DirTemplates)) {
    $null = New-Item -Path $DirTemplates -ItemType Directory
}
$null = Start-Process -FilePath $O365TemplatesExe -ArgumentList "/extract:$DirTemplates /quiet" -Wait -PassThru
Write-Log -message "Copying ADMX and ADML files to PolicyDefinitions folder."
$null = Get-ChildItem -Path $DirTemplates -File -Recurse -Filter '*.admx' | ForEach-Object { Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\" -Force }
$null = Get-ChildItem -Path $DirTemplates -Directory -Recurse | Where-Object { $_.Name -eq 'en-us' } | Get-ChildItem -File -recurse -filter '*.adml' | ForEach-Object { Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\en-us\" -Force }

Write-Log -message "Checking for lgpo.exe in '$env:SystemRoot\system32'."

If (-not(Test-Path -Path "$env:SystemRoot\System32\Lgpo.exe")) {
    $azipfiles = Get-ChildItem -Path $PSScriptRoot -filter '*.zip' -recurse
    $lgpozip = $azipfiles[0].FullName
    Write-Log -category Info -message "Expanding '$lgpozip' to '$DirTemp'."
    expand-archive -path "$lgpozip" -DestinationPath "$DirTemp" -force
    $algpoexe = Get-ChildItem -Path "$DirTemp" -filter 'lgpo.exe' -recurse
    If ($algpoexe.count -gt 0) {
        $lgpoexe=$algpoexe[0].FullName
        Write-Log -category Info -message "Copying '$lgpoexe' to '$env:SystemRoot\system32'."
        Copy-Item -Path $lgpoexe -Destination "$env:SystemRoot\System32" -force        
    }
}

If (Test-Path -Path "$env:SystemRoot\System32\Lgpo.exe") {
    Write-Log -category Info -message "Now Configuring Office 365 Group Policy."
    Write-Log -Message "Update User LGPO registry text file."
    # Turn off insider notifications
    Update-LocalGPOTextFile -Scope User -RegistryKeyPath 'Software\policies\microsoft\office\16.0\common' -RegistryValue InsiderSlabBehavior -RegistryType DWord -RegistryData 2
    
    If (($EmailCacheTime -ne 'Not Configured') -or ($CalendarSync -ne 'Not Configured') -or ($CalendarSyncMonths -ne 'Not Configured')) {
        # Enable Outlook Cached Mode
        Write-Log -Message "Configuring Outlook Cached Mode."
        Update-LocalGPOTextFile -Scope User -RegistryKeyPath 'Software\Policies\Microsoft\Office\16.0\Outlook\Cached Mode' -RegistryValue 'Enable' -RegistryType DWord -RegistryData 1
    }
    
    # Cached Exchange Mode Settings: https://support.microsoft.com/en-us/help/3115009/update-lets-administrators-set-additional-default-sync-slider-windows
    If ($EmailCacheTime -eq '3 days') { $SyncWindowSetting = 0; $SyncWindowSettingDays = 3 }
    If ($EmailCacheTime -eq '1 week') { $SyncWindowSetting = 0; $SyncWindowSettingDays = 7 }
    If ($EmailCacheTime -eq '2 weeks') { $SyncWindowSetting = 0; $SyncWindowSettingDays = 14 }
    If ($EmailCacheTime -eq '1 month') { $SyncWindowSetting = 1 }
    If ($EmailCacheTime -eq '3 months') { $SyncWindowSetting = 3 }
    If ($EmailCacheTime -eq '6 months') { $SyncWindowSetting = 6 }
    If ($EmailCacheTime -eq '12 months') { $SyncWindowSetting = 12 }
    If ($EmailCacheTime -eq '24 months') { $SyncWindowSetting = 24 }
    If ($EmailCacheTime -eq '36 months') { $SyncWindowSetting = 36 }
    If ($EmailCacheTime -eq '60 months') { $SyncWindowSetting = 60 }
    If ($EmailCacheTime -eq 'All') { $SyncWindowSetting = 0; $SyncWindowSettingDays = 0 }

    If ($SyncWindowSetting) {
        Update-LocalGPOTextFile -Scope User -RegistryKeyPath 'Software\Policies\Microsoft\Office\16.0\Outlook\Cached Mode' -RegistryValue 'SyncWindowSetting' -RegistryType DWORD -RegistryData $SyncWindowSetting
    }
    If ($SyncWindowSettingDays) {
        Update-LocalGPOTextFile -Scope User -RegistryKeyPath 'Software\Policies\Microsoft\Office\16.0\Outlook\Cached Mode' -RegistryValue 'SyncWindowSettingDays' -RegistryType DWORD -RegistryData $SyncWindowSettingDays
    }

    # Calendar Sync Settings: https://support.microsoft.com/en-us/help/2768656/outlook-performance-issues-when-there-are-too-many-items-or-folders-in
    If ($CalendarSync -eq 'Inactive') {
        $CalendarSyncWindowSetting = 0 
    }
    If ($CalendarSync -eq 'Primary Calendar Only') {
        $CalendarSyncWindowSetting = 1
    }
    If ($CalendarSync -eq 'All Calendar Folders') {
        $CalendarSyncWindowSetting = 2
    }

    If ($CaldendarSyncWindowSetting) {
        Reg LOAD HKLM\DefaultUser "$env:SystemDrive\Users\Default User\NtUser.dat"
        Set-RegistryValue -Key 'HKLM:\DefaultUser\Software\Policies\Microsoft\Office16.0\Outlook\Cached Mode' -Name CalendarSyncWindowSetting -Type DWord -Value $CalendarSyncWindowSetting
        If ($CalendarSyncMonths -ne 'Not Configured') {
            Set-RegistryValue -Key 'HKCU:\DefaultUser\Software\Policies\Microsoft\Office\16.0\Outlook\Cached Mode' -Name CalendarSyncWindowSettingMonths -Type DWord -Value $CalendarSyncMonths
        }
        Write-Log -Message "Unloading default user hive."
        $null = cmd /c REG UNLOAD "HKLM\Default" '2>&1'
        If ($LastExitCode -ne 0) {
            # sometimes the registry doesn't unload properly so we have to perform powershell garbage collection first.
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            Start-Sleep -Seconds 5
            $null = cmd /c REG UNLOAD "HKLM\Default" '2>&1'
            If ($LastExitCode -eq 0) {
                Write-Log -Message "Hive unloaded successfully."
            }
            Else {
                Write-Log -category Error -Message "Default User hive unloaded with exit code [$LastExitCode]."
            }
        }
        Else {
            Write-Log -Message "Hive unloaded successfully."
        }
    }
    Write-Log -Message "Update Computer LGPO registry text file."
    $RegistryKeyPath = 'SOFTWARE\Policies\Microsoft\Office\16.0\Common\OfficeUpdate'
    # Hide Office Update Notifications
    Update-LocalGPOTextFile -scope Computer -RegistryKeyPath $RegistryKeyPath -RegistryValue 'HideUpdateNotifications' -RegistryType DWord -RegistryData 1
    # Hide and Disable Updates
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $RegistryKeyPath -RegistryValue 'HideEnableDisableUpdates' -RegistryType DWord -RegistryData 1
    If ($DisableUpdates) {
        # Disable Updates            
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $RegistryKeyPath -RegistryValue 'EnableAutomaticUpdates' -RegistryType DWord -RegistryData 0
    }

    Invoke-LGPO -Verbose
}
Else {
    Write-Log -category Error -message "Unable to configure local policy with lgpo tool because it was not found."
    Exit 2
}

Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue