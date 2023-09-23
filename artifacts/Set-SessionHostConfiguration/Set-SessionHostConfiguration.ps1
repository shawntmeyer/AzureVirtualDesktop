[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [Hashtable] $DynParameters
)
[string]$Script:LogDir = "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension"
[string]$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
$SHKeys = $DynParameters.SHConfiguration
$ActiveDirectorySolution = $SHKeys.activeDirectorySolution
$AmdVmSize = $SHKeys.AmdVmSize
$NvidiaVmSize = $SHKeys.NvidiaVmSize
$HostPoolRegistrationToken = $SHKeys.HostPoolRegistrationToken
$SecurityWorkspaceId = $SHKeys.SecurityWorkspaceId
If ($SecurityWorkspaceId) {
    $SecurityMonitoring = $true
    $SecurityWorkspaceKey = $SHKeys.SecurityWorkspaceKey
}

$TempDir = Join-Path -Path $env:Temp -ChildPath $Script:Name
If (Test-Path -Path $TempDir) {Remove-Item -Path $TempDir -Recurse -Force}
New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

##############################################################
#region Functions

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
    Add-Content $Script:Log $content -ErrorAction Stop
}

Function Get-InternetUrl {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [uri]$Url,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$searchstring
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Try {
            Write-Verbose "${CmdletName}: Now extracting download URL from '$Url'."
            $HTML = Invoke-WebRequest -Uri $Url -UseBasicParsing
            $Links = $HTML.Links
            $ahref = $null
            $ahref=@()
            $ahref = ($Links | Where-Object {$_.href -like "*$searchstring*"}).href
            If ($ahref.count -eq 0 -or $null -eq $ahref) {
                $ahref = ($Links | Where-Object {$_.OuterHTML -like "*$searchstring*"}).href
            }
            If ($ahref.Count -eq 1) {
                Write-Verbose "${CmdletName}: Download URL = '$ahref'"
                $ahref

            }
            Elseif ($ahref.Count -gt 1) {
                Write-Verbose "${CmdletName}: Download URL = '$($ahref[0])'"
                $ahref[0]
            }
        }
        Catch {
            Write-Error "${CmdletName}: Error Downloading HTML and determining link for download."
            Exit 1
        }
    }
    End {
    }
}

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
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {

        $start_time = Get-Date

        If (!$OutputFileName) {
            Write-Verbose "${CmdletName}: No OutputFileName specified. Trying to get file name from URL."
            If ((split-path -path $Url -leaf).Contains('.')) {
                $OutputFileName = split-path -path $url -leaf
                Write-Verbose "${CmdletName}: Url contains file name - '$OutputFileName'."
            }
            Else {
                Write-Verbose "${CmdletName}: Url does not contain file name. Trying 'Location' Response Header."
                $request = [System.Net.WebRequest]::Create($url)
                $request.AllowAutoRedirect=$false
                $response=$request.GetResponse()
                $Location = $response.GetResponseHeader("Location")
                If ($Location) {
                    $OutputFileName = [System.IO.Path]::GetFileName($Location)
                    Write-Verbose "${CmdletName}: File Name from 'Location' Response Header is '$OutputFileName'."
                }
                Else {
                    Write-Verbose "${CmdletName}: No 'Location' Response Header returned. Trying 'Content-Disposition' Response Header."
                    $result = Invoke-WebRequest -Method GET -Uri $Url -UseBasicParsing
                    $contentDisposition = $result.Headers.'Content-Disposition'
                    If ($contentDisposition) {
                        $OutputFileName = $contentDisposition.Split("=")[1].Replace("`"","")
                        Write-Verbose "${CmdletName}: File Name from 'Content-Disposition' Response Header is '$OutputFileName'."
                    }
                }
            }
        }

        If ($OutputFileName) { 
            $wc = New-Object System.Net.WebClient
            $OutputFile = Join-Path $OutputDirectory $OutputFileName
            If (Test-Path -Path $OutputFile) {
                Remove-Item -Path $OutputFile -Force
            }
            Write-Verbose "${CmdletName}: Downloading file at '$url' to '$OutputFile'."
            Try {
                $wc.DownloadFile($url, $OutputFile)
                $time = (Get-Date).Subtract($start_time).Seconds
                
                Write-Verbose "Time taken: '$time' seconds."
                if (Test-Path -Path $outputfile) {
                    $totalSize = (Get-Item $outputfile).Length / 1MB
                    Write-Verbose "${CmdletName}: Download was successful. Final file size: '$totalsize' mb"
                    $OutputFile
                }
            }
            Catch {
                Write-Error "${CmdletName}: Error downloading file. Please check url."
                Exit 2
            }
        }
        Else {
            Write-Error "${CmdletName}: No OutputFileName specified. Unable to download file."
            Exit 2
        }
    }
    End {
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
        [ValidateSet('DWORD', 'String', 'MultiString')]
        [string]$RegistryType,
        [Parameter(Mandatory = $false, ParameterSetName = 'Delete')]
        [switch]$Delete,
        [Parameter(Mandatory = $false, ParameterSetName = 'DeleteAllValues')]
        [switch]$DeleteAllValues,
        [string]$outputDir = $TempDir,
        [string]$outfileprefix = $Script:Name
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        # Convert $RegistryType to UpperCase to prevent LGPO errors.
        $ValueType = $RegistryType.ToUpper()
        # Change String type to SZ for text file
        If ($ValueType -eq 'STRING') { $ValueType = 'SZ' }
        If ($ValueType -eq 'MultiString') { $ValueType = 'MULTISZ'}
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

        Write-Verbose "${CmdletName}: Adding registry information to '$outfile' for LGPO.exe"
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
        [string]$InputDir = $TempDir,
        [string]$SearchTerm
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Write-Verbose "${CmdletName}: Gathering Registry text files for LGPO from '$InputDir'"
        If ($SearchTerm) {
            $InputFiles = Get-ChildItem -Path $InputDir -Filter "$SearchTerm*.txt"
        }
        Else {
            $InputFiles = Get-ChildItem -Path $InputDir -Filter '*.txt'
        }
        ForEach ($RegistryFile in $inputFiles) {
            $TxtFilePath = $RegistryFile.FullName
            Write-Verbose "${CmdletName}: Now applying settings from '$txtFilePath' to Local Group Policy via LGPO.exe."
            $lgporesult = Start-Process -FilePath 'lgpo.exe' -ArgumentList "/t `"$TxtFilePath`"" -Wait -PassThru
            Write-Verbose "${CmdletName}: LGPO exitcode: '$($lgporesult.exitcode)'"
        }
    }
    End {
    }
}

Function Set-RegistryValue {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Name,
        [Parameter()]
        [string]
        $Path,
        [Parameter()]
        [string]$PropertyType,
        [Parameter()]
        $Value
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        $LogOutputValue = "Path: $Path, Name: $Name , PropertyType: $PropertyType, Value: $Value"
        # Create the registry Key(s) if necessary.
        If(!(Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        # Check for existing registry setting
        $ExistingValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        If ($ExistingValue) {
            # Get current Value
            $CurrentValue = Get-ItemPropertyValue -Path $Path -Name $Name
            Write-Verbose "${CmdletName}: Existing Registry Value Found - Path: $Path, Name: $Name, PropertyType: $PropertyType, Value: $CurrentValue"
            If ($Value -ne $CurrentValue) {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force | Out-Null
                Write-Verbose "${CmdletName}: Updated registry setting: $LogOutputValue"
            } Else {
                Write-Verbose "${CmdletName}: Registry Setting exists with correct value: $LogOutputValue"
            }
        } Else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value -Force | Out-Null
            Write-Verbose "${CmdletName}: Added registry setting: $LogOutputValue"
        }
        Start-Sleep -Milliseconds 500
    }
    End {
    }
}


#endregion
New-Log -Path $Script:LogDir | Out-Null
Write-Log -message "Starting '$PSCommandPath'."

try 
{
    ##############################################################
    #  Run the Virtual Desktop Optimization Tool (VDOT)
    ##############################################################
    # https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool
    <# if($ImagePublisher -eq 'MicrosoftWindowsDesktop' -and $ImageOffer -ne 'windows-7')
    {
        # Download VDOT
        $URL = 'https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip'
        $ZIP = 'VDOT.zip'
        Invoke-WebRequest -Uri $URL -OutFile $ZIP
        
        # Extract VDOT from ZIP archive
        Expand-Archive -LiteralPath $ZIP -Force
        
        # Fix to disable AppX Packages
        # As of 2/8/22, all AppX Packages are enabled by default
        $Files = (Get-ChildItem -Path .\VDOT\Virtual-Desktop-Optimization-Tool-main -File -Recurse -Filter "AppxPackages.json").FullName
        foreach($File in $Files)
        {
            $Content = Get-Content -Path $File
            $Settings = $Content | ConvertFrom-Json
            $NewSettings = @()
            foreach($Setting in $Settings)
            {
                $NewSettings += [pscustomobject][ordered]@{
                    AppxPackage = $Setting.AppxPackage
                    VDIState = 'Disabled'
                    URL = $Setting.URL
                    Description = $Setting.Description
                }
            }

            $JSON = $NewSettings | ConvertTo-Json
            $JSON | Out-File -FilePath $File -Force
        }

        # Run VDOT
        & .\VDOT\Virtual-Desktop-Optimization-Tool-main\Windows_VDOT.ps1 -Optimizations 'AppxPackages','Autologgers','DefaultUserSettings','LGPO','NetworkOptimizations','ScheduledTasks','Services','WindowsMediaPlayer' -AdvancedOptimizations 'Edge','RemoveLegacyIE' -AcceptEULA


        Write-Log -Message 'Optimized the operating system using VDOT' -Type 'INFO'
    } #>

    ##############################################################
    #  Add Recommended AVD Settings
    ##############################################################
    If (!(Test-Path -Path "$env:SystemRoot\System32\lgpo.exe")) {
        Try {
            $fileLGPO = (Get-ChildItem -Path $PSScriptRoot -File -Filter 'lgpo.exe').FullName
            If (-not $fileLGPO) {
                $urlLGPO = 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip'
                $outputDir = $TempDir
                $fileLGPODownload = Get-InternetFile -Url $urlLGPO -OutputDirectory $env:Temp -ErrorAction SilentlyContinue
                Expand-Archive -Path $fileLGPODownload -DestinationPath $outputDir -Force
                Remove-Item $fileLGPODownload -Force
                $fileLGPO = (Get-ChildItem -Path $outputDir -file -Filter 'lgpo.exe' -Recurse)[0].FullName
            }
            Write-Log -category Info -Message "Copying `"$fileLGPO`" to System32"
            Copy-Item -Path $fileLGPO -Destination "$env:SystemRoot\System32" -Force
        } Catch {
            Write-Log -category Warning -Message "LGPO.exe could not be found or downloaded. Unable to apply local group policy object settings."
        }    
    }

    If (Test-Path -Path "$env:SystemRoot\System32\lgpo.exe") {
        # Disable Automatic Updates: https://learn.microsoft.com/azure/virtual-desktop/set-up-customize-master-image#disable-automatic-updates
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -RegistryValue 'NoAutoUpdate' -RegistryType DWORD -RegistryData 1
        # Enable Time Zone Redirection: https://learn.microsoft.com/azure/virtual-desktop/set-up-customize-master-image#set-up-time-zone-redirection
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -RegistryValue 'fEnableTimeZoneRedirection' -RegistryType DWORD -RegistryData 1
    
        ##############################################################
        #  Add GPU Settings
        ##############################################################
        # This setting applies to the VM Size's recommended for AVD with a GPU
        if ($AmdVmSize -or $NvidiaVmSize) 
        {
            # Configure GPU-accelerated app rendering: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-app-rendering
            Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -RegistryValue 'bEnumerateHWBeforeSW' -RegistryType DWORD -RegistryData 1

            # Configure fullscreen video encoding: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-fullscreen-video-encoding
            Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -RegistryValue 'AVC444ModePreferred' -RegistryType DWORD -RegistryData 1
        }

        # This setting applies only to VM Size's recommended for AVD with a Nvidia GPU
        if($NvidiaVmSize)
        {
            # Configure GPU-accelerated frame encoding: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-frame-encoding
            Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -RegistryValue 'AVChardwareEncodePreferred' -RegistryType DWORD -RegistryData 1
        }
        Invoke-LGPO -InputDir $TempDir
    }

    ##############################################################
    #  Install the AVD Agent
    ##############################################################
    # Disabling this method for installing the AVD agent until AAD Join can completed successfully
    $BootInstallerMSI = 'AVD-Bootloader.msi'
    $BootInstaller = (Get-ChildItem $PSScriptRoot -Filter "$BootInstallerMSI" -Recurse).FullName
    If (!$BootInstaller) {
        $url = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
        $BootInstallerMSI = Get-InternetFile -Url $urlLGPO -OutputDirectory $TempDir -OutputFileName $BootInstallerMSI -ErrorAction SilentlyContinue
    }
    $Install = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $BootInstaller /quiet /norestart" -Wait -Passthru
    If ($($Install.ExitCode) -eq 0) {
        Write-Log -category Info -message "'AVD Boot loader' installed successfully."
    }
    Else {
        Write-Log -category Warning -message "The Installer exit code is $($Installer.ExitCode)"
    }
    Start-Sleep -Seconds 5 | Out-Null

    $AgentInstallerMSI = 'AVD-Bootloader.msi'
    $AgentInstaller = (Get-ChildItem $PSScriptRoot -Filter "$AgentInstallerMSI" -Recurse).FullName
    If (!$AgentInstaller) {
        $url = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
        $AgentInstallerMSI = Get-InternetFile -Url $urlLGPO -OutputDirectory $TempDir -OutputFileName $AgentInstallerMSI -ErrorAction SilentlyContinue
    }
    $Install = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $AgentInstaller /quiet /norestart REGISTRATIONTOKEN=$HostPoolRegistrationToken" -Wait -Passthru
    If ($($Install.ExitCode) -eq 0) {
        Write-Log -category Info -message "'AVD Boot loader' installed successfully."
    }
    Else {
        Write-Log -category Warning -message "The Installer exit code is $($Installer.ExitCode)"
    }
    Start-Sleep -Seconds 5 | Out-Null

    ##############################################################
    #  Dual-home Microsoft Monitoring Agent for Azure Sentinel or Defender for Cloud
    ##############################################################
    if($SecurityMonitoring -eq 'true')
    {
        $mma = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
        $mma.AddCloudWorkspace($SecurityWorkspaceId, $SecurityWorkspaceKey)
        $mma.ReloadConfiguration() | Out-Null
    }

    ##############################################################
    #  Restart VM
    ##############################################################
    if(($ActiveDirectorySolution -eq "AzureActiveDirectory" -or $ActiveDirectorySolution -eq "AzureActiveDirectoryIntuneEnrollment") -and !$AmdVmSize -and !$NvidiaVmSize)
    {
        Start-Process -FilePath 'shutdown' -ArgumentList '/r /t 30' | Out-Null
    }
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
catch 
{
    Write-Log -category Error -Message $_
    throw
}
