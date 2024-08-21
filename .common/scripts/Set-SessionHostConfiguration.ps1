param (
    [string]$AmdVmSize,
    [string]$NvidiaVmSize,
    [string]$DisableUpdates
)

##############################################################
#region Functions
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

try 
{ 
    ##############################################################
    #  Add Recommended AVD Settings
    ##############################################################
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
    if ($AmdVmSize -eq 'true' -or $NvidiaVmSize -eq 'true') 
    {
        # Configure GPU-accelerated app rendering: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-app-rendering
        $RegSettings.Add(@{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'bEnumerateHWBeforeSW'; PropertyType = 'DWORD'; Value = 1})
        # Configure fullscreen video encoding: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-fullscreen-video-encoding
        $RegSettings.Add(@{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'AVC444ModePreferred'; PropertyType = 'DWORD'; Value = 1})
    }

    # This setting applies only to VM Size's recommended for AVD with a Nvidia GPU
    if($NvidiaVmSize -eq 'true')
    {
        # Configure GPU-accelerated frame encoding: https://learn.microsoft.com/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-frame-encoding
        $RegSettings.Add(@{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'AVChardwareEncodePreferred'; PropertyType = 'DWORD'; Value = 1})
    }

    ForEach ($Setting in $RegSettings) {
        Set-RegistryValue -Name $Setting.Name -Path $Setting.Path -PropertyType $Setting.PropertyType -Value $Setting.Value -Verbose
    }
}
catch 
{
    throw
}
