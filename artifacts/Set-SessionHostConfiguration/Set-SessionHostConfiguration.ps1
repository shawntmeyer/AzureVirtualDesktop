[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [Hashtable] $DynParameters
)
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

[string]$LogDir = "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension"
[string]$ScriptName = "Set-SessionHostConfiguration"
[string]$Log = Join-Path -Path $LogDir -ChildPath "$ScriptName.log"
Start-Transcript -Path "$Log" -Force
$TempDir = Join-Path -Path $env:Temp -ChildPath $ScriptName

##############################################################
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
        [string]$outfileprefix = $ScriptName
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
        $LogOutputValue = 'Path: ' + $Path + ', Name: ' + $Name + ', PropertyType: ' + $PropertyType + ', Value: ' + $Value
        # Create the registry Key(s) if necessary.
        If(!(Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        # Check for existing registry setting
        $ExistingValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        If ($ExistingValue) {
            # Get current Value
            $CurrentValue = Get-ItemPropertyValue -Path $Path -Name $Name
            Write-Verbose ${CmdletName} + ': Existing Registry Value Found - Path: ' + $Path + ', Name: ' + $Name + ', PropertyType: ' + $PropertyType + ', Value: ' + $CurrentValue
            If ($Value -ne $CurrentValue) {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force | Out-Null
                Write-Verbose ${CmdletName} + ': Updated registry setting:' + $LogOutputValue
            } Else {
                Write-Verbose ${CmdletName} + ': Registry Setting exists with correct value: ' + $LogOutputValue
            }
        } Else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value -Force | Out-Null
            Write-Verbose ${CmdletName} + ': Added registry setting: ' + $LogOutputValue
        }
        Start-Sleep -Milliseconds 500
    }
    End {
    }
}

#endregion

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
 
    # Disable Automatic Updates: https://learn.microsoft.com/azure/virtual-desktop/set-up-customize-master-image#disable-automatic-updates
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -RegistryValue 'NoAutoUpdate' -RegistryType DWORD -RegistryData 1 -Verbose
    # Enable Time Zone Redirection: https://learn.microsoft.com/azure/virtual-desktop/set-up-customize-master-image#set-up-time-zone-redirection
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -RegistryValue 'fEnableTimeZoneRedirection' -RegistryType DWORD -RegistryData 1 -Verbose
 
    ##############################################################
    #  Add GPU Settings
    ##############################################################
    # This setting applies to the VM Size's recommended for AVD with a GPU
    if ($AmdVmSize -or $NvidiaVmSize) 
    {
        # Configure GPU-accelerated app rendering: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-app-rendering
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -RegistryValue 'bEnumerateHWBeforeSW' -RegistryType DWORD -RegistryData 1 -Verbose

        # Configure fullscreen video encoding: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-fullscreen-video-encoding
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -RegistryValue 'AVC444ModePreferred' -RegistryType DWORD -RegistryData 1 -Verbose
    }

    # This setting applies only to VM Size's recommended for AVD with a Nvidia GPU
    if($NvidiaVmSize)
    {
        # Configure GPU-accelerated frame encoding: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-frame-encoding
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -RegistryValue 'AVChardwareEncodePreferred' -RegistryType DWORD -RegistryData 1 -Verbose
    }

    ##############################################################
    #  Install the AVD Agent
    ##############################################################
    # Disabling this method for installing the AVD agent until AAD Join can completed successfully
    $BootInstaller = 'AVD-Bootloader.msi'
    Get-WebFile -FileName $BootInstaller -URL 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
    Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $BootInstaller /quiet /qn /norestart /passive" -Wait -Passthru | Out-Null
    Write-Log -Message 'Installed AVD Bootloader' -Type 'INFO'
    Start-Sleep -Seconds 5 | Out-Null

    $AgentInstaller = 'AVD-Agent.msi'
    Get-WebFile -FileName $AgentInstaller -URL 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
    Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $AgentInstaller /quiet /qn /norestart /passive REGISTRATIONTOKEN=$HostPoolRegistrationToken" -Wait -PassThru | Out-Null
    Write-Log -Message 'Installed AVD Agent' -Type 'INFO'
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

    $Output = [pscustomobject][ordered]@{
        activeDirectorySolution = $ActiveDirectorySolution
    }
    $JsonOutput = $Output | ConvertTo-Json
    return $JsonOutput
}
catch 
{
    Write-Log -Message $_ -Type 'ERROR'
    throw
}
