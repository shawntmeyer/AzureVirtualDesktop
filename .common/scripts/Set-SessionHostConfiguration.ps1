param (
    [string]$AmdVmSize,
    [string]$NvidiaVmSize,
    [string]$DisableUpdates
)

function New-Log {
    Param (
        [Parameter(Position = 0)]
        [string] $Path
    )
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
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet("Info", "Warning", "Error")]
        $category = 'Info',
        [Parameter(Mandatory = $true, Position = 1)]
        $message
    )
    $date = get-date
    $content = "[$date]`t$category`t`t$message" 
    Add-Content $Script:Log $content -ErrorAction Stop
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
        Write-Log -message "[Set-RegistryValue]: Setting Registry Value: $Name"
    }
    Process {
        # Create the registry Key(s) if necessary.
        If (!(Test-Path -Path $Path)) {
            Write-Log -message "[Set-RegistryValue]: Creating Registry Key: $Path"
            New-Item -Path $Path -Force | Out-Null
        }
        # Check for existing registry setting
        $RemoteValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        If ($RemoteValue) {
            # Get current Value
            $CurrentValue = Get-ItemPropertyValue -Path $Path -Name $Name
            Write-Log -message "[Set-RegistryValue]: Current Value of $($Path)\$($Name) : $CurrentValue"
            If ($Value -ne $CurrentValue) {
                Write-Log -message "[Set-RegistryValue]: Setting Value of $($Path)\$($Name) : $Value"
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force | Out-Null
            } Else {
                Write-Log -message "[Set-RegistryValue]: Value of $($Path)\$($Name) is already set to $Value"
            }           
        }
        Else {
            Write-Log -message "[Set-RegistryValue]: Setting Value of $($Path)\$($Name) : $Value"
            New-ItemProperty -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value -Force | Out-Null
        }
        Start-Sleep -Milliseconds 500
    }
    End {
    }
}

[string]$Script:LogDir = Join-Path -Path $Env:SystemRoot -ChildPath 'Logs'
[string]$Script:Name = 'Set-SessionHostConfiguration'
New-Log -Path $Script:LogDir
write-log -message "*** Parameter Values ***"
Write-Log -message "AmdVmSize: $AmdVmSize"
Write-Log -message "NvidiaVmSize: $NvidiaVmSize"
Write-Log -message "DisableUpdates: $DisableUpdates"
try 
{ 
    ##############################################################
    #  Add Recommended AVD Settings
    ##############################################################
    Write-Log -message "*** Building Array of Registry Settings ***"
    $RegSettings = New-Object System.Collections.ArrayList
    If ($DisableUpdates -eq 'true') {
        # Disable Automatic Updates: https://learn.microsoft.com/azure/virtual-desktop/set-up-customize-master-image#disable-automatic-updates
        $RegSettings.Add(@{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate'; PropertyType = 'DWORD'; Value = 1})
    }
    # Enable Time Zone Redirection: https://learn.microsoft.com/azure/virtual-desktop/set-up-customize-master-image#set-up-time-zone-redirection
    $RegSettings.Add(@{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'fEnableTimeZoneRedirection'; PropertyType = 'DWORD'; Value = 1})
    
    ##############################################################
    #  Add GPU Settings
    ##############################################################
    # This setting applies to the VM Size's recommended for AVD with a GPU
    if ($AmdVmSize -eq 'true' -or $NvidiaVmSize -eq 'true') {
        Write-Log -message "Adding GPU Settings"
        # Configure GPU-accelerated app rendering: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-app-rendering
        $RegSettings.Add(@{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'bEnumerateHWBeforeSW'; PropertyType = 'DWORD'; Value = 1})
        # Configure fullscreen video encoding: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-fullscreen-video-encoding
        $RegSettings.Add(@{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'AVC444ModePreferred'; PropertyType = 'DWORD'; Value = 1})
    }

    # This setting applies only to VM Size's recommended for AVD with a Nvidia GPU
    if($NvidiaVmSize -eq 'true') {
        Write-Log -message "Adding Nvidia GPU Settings"
        # Configure GPU-accelerated frame encoding: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-frame-encoding
        $RegSettings.Add(@{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'AVChardwareEncodePreferred'; PropertyType = 'DWORD'; Value = 1})
    }
    Write-Log -message "Adding Registry Settings"
    ForEach ($Setting in $RegSettings) {
        Set-RegistryValue -Name $Setting.Name -Path $Setting.Path -PropertyType $Setting.PropertyType -Value $Setting.Value -Verbose
    }

    # Resize OS Disk
    Write-Log -message "Resizing OS Disk"
    $driveLetter = $env:SystemDrive.Substring(0,1)
    $size = Get-PartitionSupportedSize -DriveLetter $driveLetter
    Resize-Partition -DriveLetter $driveLetter -Size $size.SizeMax
    Write-Log -message "OS Disk Resized"
    Write-Log -message "Done"
}
catch 
{
    throw
}
