[CmdletBinding(SupportsShouldProcess = $true)]
param (
    #JSON String of the SmartScreenAllowListDomains
    # https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#smartscreenallowlistdomains
    [Parameter(Mandatory = $false)]
    [string]$SmartScreenAllowListDomains = '["portal.azure.com", "core.windows.net", "portal.azure.us", "usgovcloudapi.net"]',

    #JSON String of the PopupsAllowedForUrls
    # https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#popupsallowedforurls
    [Parameter(Mandatory = $false)]
    [string]$PopupsAllowedForUrls = '["[*.]mil","[*.]gov","[*.]portal.azure.us","[*.]usgovcloudapi.net","[*.]azure.com","[*.]azure.net"]'
)
[String]$AppName = 'Edge'
[string]$LogDir = "$env:SystemRoot\Logs\Configuration"
[string]$ScriptName = "Configure-EdgePolicy"
[string]$Log = Join-Path -Path $LogDir -ChildPath "$ScriptName.log"
[string]$TempDir = Join-Path -Path $env:Temp -ChildPath $ScriptName

[array]$SmartScreenAllowListDomains = $SmartScreenAllowListDomains.Replace('\"', '"').Replace('\[', '[').Replace('\]', ']') | ConvertFrom-Json
[array]$PopupsAllowedForUrls = $PopupsAllowedForUrls.Replace('\"', '"').Replace('\[', '[').Replace('\]', ']') | ConvertFrom-Json

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

Write-Log -category Info -message "Running Script to Configure Microsoft Edge Policies."

$EdgeTemplatesCab = (Get-ChildItem -Path $PSScriptRoot -Filter '*.cab').FullName
$TemplatesDir = Join-Path -Path $TempDir -ChildPath 'Templates'
New-Item -Path $TemplatesDir -ItemType Directory -Force | out-null
Write-Log -category Info -message "Expanding `"$EdgeTemplatesCab`" into `"$TemplatesDir`"."
& cmd /c extrac32 /Y /E $EdgeTemplatesCab /L "$TemplatesDir"
$EdgeTemplatesZip = Get-ChildItem -Path "$TemplatesDir" -Filter '*.zip' -File -Recurse
$EdgeTemplatesZip = $EdgeTemplatesZip[0].FullName
Expand-Archive -Path $EdgeTemplatesZip -DestinationPath "$TemplatesDir" -force
Write-Log -category Info -message "Copy ADMX and ADML files to PolicyDefinition Folders."

$null = Get-ChildItem -Path "$TemplatesDir" -File -Recurse -Filter '*.admx' | ForEach-Object { Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\" -Force }
$null = Get-ChildItem -Path "$TemplatesDir" -Directory -Recurse | Where-Object { $_.Name -eq 'en-us' } | Get-ChildItem -File -recurse -filter '*.adml' | ForEach-Object { Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\en-us\" -Force }

Write-Log -message "Checking for lgpo.exe in '$env:SystemRoot\system32'."

If (-not(Test-Path -Path "$env:SystemRoot\System32\Lgpo.exe")) {
    $LGPOZipFile = Join-Path -Path $PSScriptRoot -ChildPath 'LGPO.zip'
    Write-Log -category Info -message "Expanding '$LGPOZipFile' to '$DirTemp'."
    expand-archive -path "$LGPOZipFile" -DestinationPath "$DirTemp" -force
    $LGPOExe = Get-ChildItem -Path "$DirTemp" -filter 'lgpo.exe' -recurse
    If ($LGPOExe.count -gt 0) {
        [string]$LGPOExe = $LGPOExe[0].FullName
        Write-Log -category Info -message "Copying '$LGPOExe' to '$env:SystemRoot\system32'."
        Copy-Item -Path $LGPOExe -Destination "$env:SystemRoot\System32" -force        
    }
}

If (Test-Path -Path "$env:SystemRoot\System32\Lgpo.exe") {
    Write-Log -category Info -message "Now Configuring Edge Group Policy."
    # https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#hidefirstrunexperience
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'HideFirstRunExperience' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    # https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#nonremovableprofileenabled
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'NonRemovableProfileEnabled' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    # https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#proxysettings
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'ProxySettings' -Delete -outfileprefix $appName -Verbose
    # https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#automatichttpsdefault
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'AutomaticHttpsDefault' -RegistryData 0 -RegistryType DWORD -outfileprefix $appName -Verbose
    # https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#downloadrestrictions
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge' -RegistryValue 'DownloadRestrictions' -RegistryType 'DWord' -RegistryData 4 -outfileprefix $appName -Verbose
    if ($null -ne $SmartScreenAllowListDomains -and $SmartScreenAllowListDomains.Count -gt 0) {
        Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge\SmartScreenAllowListDomains' -RegistryValue '*' -DeleteAllValues -outfileprefix $appName -Verbose
        $i = 1
        ForEach ($domain in $SmartScreenAllowListDomains) {
            Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge\SmartScreenAllowListDomains' -RegistryValue $i -RegistryType 'STRING' -RegistryData $domain -outfileprefix $appName -Verbose        $i++
       
        }
    }
    if ($null -ne $PopupsAllowedForUrls -and $PopupsAllowedForUrls.Count -gt 0) {
        Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge\PopupsAllowedForUrls' -RegistryValue '*' -DeleteAllValues -outfileprefix $appName -Verbose
        $i = 1
        ForEach ($url in $PopupsAllowedForUrls) {
            Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'Software\Policies\Microsoft\Edge\PopupsAllowedForUrls' -RegistryValue $i -RegistryType 'STRING' -RegistryData $url -outfileprefix $appName -Verbose
            $i++
        }
    }
    Invoke-LGPO -Verbose
}
Else {
    Write-Log -category Error -message "Unable to configure local policy with lgpo tool because it was not found."
    Exit 2
}

Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue