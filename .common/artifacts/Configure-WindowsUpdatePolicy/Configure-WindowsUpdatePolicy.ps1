[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$DeferQualityUpdatesPeriodInDays = '4'
)

#region Functions

Function Get-InternetFile {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [uri]$Url,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$OutputDirectory,
        [Parameter(Mandatory = $false, Position = 2)]
        [string]$OutputFileName
    )

    Begin {
        $ProgressPreference = 'SilentlyContinue'
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Message "Starting ${CmdletName} with the following parameters: $PSBoundParameters"
    }
    Process {

        $start_time = Get-Date

        If (!$OutputFileName) {
            Write-Log -Message "${CmdletName}: No OutputFileName specified. Trying to get file name from URL."
            If ((split-path -path $Url -leaf).Contains('.')) {
                $OutputFileName = split-path -path $url -leaf
                Write-Log -Message "${CmdletName}: Url contains file name - '$OutputFileName'."
            }
            Else {
                Write-Log -Message "${CmdletName}: Url does not contain file name. Trying 'Location' Response Header."
                $request = [System.Net.WebRequest]::Create($url)
                $request.AllowAutoRedirect=$false
                $response=$request.GetResponse()
                $Location = $response.GetResponseHeader("Location")
                If ($Location) {
                    $OutputFileName = [System.IO.Path]::GetFileName($Location)
                    Write-Log -Message "${CmdletName}: File Name from 'Location' Response Header is '$OutputFileName'."
                }
                Else {
                    Write-Log -Message "${CmdletName}: No 'Location' Response Header returned. Trying 'Content-Disposition' Response Header."
                    $result = Invoke-WebRequest -Method GET -Uri $Url -UseBasicParsing
                    $contentDisposition = $result.Headers.'Content-Disposition'
                    If ($contentDisposition) {
                        $OutputFileName = $contentDisposition.Split("=")[1].Replace("`"","")
                        Write-Log -Message "${CmdletName}: File Name from 'Content-Disposition' Response Header is '$OutputFileName'."
                    }
                }
            }
        }

        If ($OutputFileName) { 
            $wc = New-Object System.Net.WebClient
            $OutputFile = Join-Path $OutputDirectory $OutputFileName
            Write-Log -Message "${CmdletName}: Downloading file at '$url' to '$OutputFile'."
            Try {
                $wc.DownloadFile($url, $OutputFile)
                $time = (Get-Date).Subtract($start_time).Seconds
                
                Write-Log -Message "${CmdletName}: Time taken: '$time' seconds."
                if (Test-Path -Path $outputfile) {
                    $totalSize = (Get-Item $outputfile).Length / 1MB
                    Write-Log -Message "${CmdletName}: Download was successful. Final file size: '$totalsize' mb"
                    Return $OutputFile
                }
            }
            Catch {
                Write-Log -Category Error -Message "${CmdletName}: Error downloading file. Please check url."
                Return $Null
            }
        }
        Else {
            Write-Log -Category Error -Message "${CmdletName}: No OutputFileName specified. Unable to download file."
            Return $Null
        }
    }
    End {
        Write-Log -Message "Ending ${CmdletName}"
    }
}

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
        [string]$outputDir = "$Script:TempDir\LGPO",
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
        [string]$InputDir = "$Script:TempDir\LGPO",
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
[int]$DeferQualityUpdatesPeriodInDays = $DeferQualityUpdatesPeriodInDays
[string]$AppName = 'WindowsUpdatePolicy'
[string]$Script:Name = "Configure-WindowsUpdatePolicy"
[string]$Script:TempDir = Join-Path -Path $env:Temp -ChildPath $ScriptName
[string]$LGPO = "$env:SystemRoot\System32\lgpo.exe"
$null = New-Item -Path $Script:TempDir -ItemType Directory -Force
New-Log -Path (Join-Path -Path $env:SystemRoot -ChildPath 'Logs')
$ErrorActionPreference = 'Stop'
Write-Log -category Info -message "Starting '$PSCommandPath'."
#endregion

Write-Log -message "Checking for 'lgpo.exe' in '$env:SystemRoot\system32'."

If (-not(Test-Path -Path $LGPO)) {
    Write-Log -category Info -message "'lgpo.exe' not found in '$env:SystemRoot\system32'."
    $LGPOZip = Join-Path -Path $PSScriptRoot -ChildPath 'LGPO.zip'
    If (-not(Test-Path -Path $LGPOZip)) {
        Write-Log -category Info -Message "Downloading LGPO tool."
        $LGPOZip = Get-InternetFile -Url 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip' -OutputDirectory $Script:TempDir -Verbose    
    }
    Write-Log -Category Info -Message "Expanding '$LGPOZip' to '$Script:TempDir'."
    Expand-Archive -Path $LGPOZip -DestinationPath $Script:TempDir -Force
    $fileLGPO = (Get-ChildItem -Path $Script:TempDir -Filter 'lgpo.exe' -Recurse)[0].FullName
    Write-Log -Message "Copying '$fileLGPO' to '$env:SystemRoot\system32'."
    Copy-Item -Path $fileLGPO -Destination "$env:SystemRoot\System32" -Force
}

If (Test-Path -Path $LGPO) {

    $regKey = "Software\Policies\Microsoft\Windows\WindowsUpdate"
    Write-Log -category info -message "Now Configuring Windows Update Settings."
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'DeferQualityUpdates' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'DeferQualityUpdatesPeriodInDays' -RegistryType 'DWORD' -RegistryData 4 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'SetComplianceDeadline' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ConfigureDeadlineForQualityUpdates' -RegistryType 'DWORD' -RegistryData 3 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ConfigureDeadlineGracePeriod' -RegistryType 'DWORD' -RegistryData 2 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ConfigureDeadlineForFeatureUpdates' -RegistryType 'DWORD' -RegistryData 7 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ConfigureDeadlineGracePeriodForFeatureUpdates' -RegistryType 'DWORD' -RegistryData 2 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ConfigureDeadlineNoAutoReboot' -Delete -outfileprefix $appName -Verbose

    $regKey = "Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'AllowMUUpdateService' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'AUOptions' -RegistryType 'DWORD' -RegistryData 4 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'AutomaticMaintenanceEnabled' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'DetectionFrequencyEnabled' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'DetectionFrequency' -RegistryType 'DWORD' -RegistryData 6 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'NoAutoUpdate' -RegistryType 'DWORD' -RegistryData 0 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ScheduledInstallDay' -RegistryType 'DWORD' -RegistryData 0 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ScheduledInstallTime' -RegistryType 'DWORD' -RegistryData 24 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ScheduledInstallEveryWeek' -RegistryType 'DWORD' -RegistryData 1 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ScheduleInstallFirstWeek' -Delete -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ScheduleInstallSecondWeek' -Delete -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ScheduleInstallThirdWeek' -Delete -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'ScheduleInstallFourthWeek' -Delete -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath $regKey -RegistryValue 'IncludeRecommendedUpdates' -Delete -outfileprefix $appName -Verbose

    Invoke-LGPO -Verbose
    Write-Log -category Info -message "Completed configuring Windows Update Settings."

}
Else {
    Write-Log -category Error -message "Unable to configure local policy with lgpo tool because it was not found."
    Exit 2
}

Remove-Item -Path $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue