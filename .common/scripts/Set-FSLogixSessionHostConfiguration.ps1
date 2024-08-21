[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$CloudCache = 'false',
    [string]$Shares,
    [string]$StorageAccountNames,
    [string]$StorageAccountKeys,
    [string]$StorageAccountDNSSuffix
)

#region Functions

Function Get-InstalledApplication {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [string[]]$Name,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [string]$ProductCode
    )

    Begin {
        [string[]]$regKeyApplications = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    }
    Process { 
        ## Enumerate the installed applications from the registry for applications that have the "DisplayName" property
        [psobject[]]$regKeyApplication = @()
        ForEach ($regKey in $regKeyApplications) {
            If (Test-Path -LiteralPath $regKey -ErrorAction 'SilentlyContinue' -ErrorVariable '+ErrorUninstallKeyPath') {
                [psobject[]]$UninstallKeyApps = Get-ChildItem -LiteralPath $regKey -ErrorAction 'SilentlyContinue' -ErrorVariable '+ErrorUninstallKeyPath'
                ForEach ($UninstallKeyApp in $UninstallKeyApps) {
                    Try {
                        [psobject]$regKeyApplicationProps = Get-ItemProperty -LiteralPath $UninstallKeyApp.PSPath -ErrorAction 'Stop'
                        If ($regKeyApplicationProps.DisplayName) { [psobject[]]$regKeyApplication += $regKeyApplicationProps }
                    }
                    Catch {
                        Continue
                    }
                }
            }
        }

        ## Create a custom object with the desired properties for the installed applications and sanitize property details
        [psobject[]]$installedApplication = @()
        ForEach ($regKeyApp in $regKeyApplication) {
            Try {
                [string]$appDisplayName = ''
                [string]$appDisplayVersion = ''
                [string]$appPublisher = ''

                ## Bypass any updates or hotfixes
                If (($regKeyApp.DisplayName -match '(?i)kb\d+') -or ($regKeyApp.DisplayName -match 'Cumulative Update') -or ($regKeyApp.DisplayName -match 'Security Update') -or ($regKeyApp.DisplayName -match 'Hotfix')) {
                    Continue
                }

                ## Remove any control characters which may interfere with logging and creating file path names from these variables
                $appDisplayName = $regKeyApp.DisplayName -replace '[^\u001F-\u007F]', ''
                $appDisplayVersion = $regKeyApp.DisplayVersion -replace '[^\u001F-\u007F]', ''
                $appPublisher = $regKeyApp.Publisher -replace '[^\u001F-\u007F]', ''

                ## Determine if application is a 64-bit application
                [boolean]$Is64BitApp = If (($is64Bit) -and ($regKeyApp.PSPath -notmatch '^Microsoft\.PowerShell\.Core\\Registry::HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node')) { $true } Else { $false }

                If ($ProductCode) {
                    ## Verify if there is a match with the product code passed to the script
                    If ($regKeyApp.PSChildName -match [regex]::Escape($productCode)) {
                        $installedApplication += New-Object -TypeName 'PSObject' -Property @{
                            UninstallSubkey    = $regKeyApp.PSChildName
                            ProductCode        = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
                            DisplayName        = $appDisplayName
                            DisplayVersion     = $appDisplayVersion
                            UninstallString    = $regKeyApp.UninstallString
                            InstallSource      = $regKeyApp.InstallSource
                            InstallLocation    = $regKeyApp.InstallLocation
                            InstallDate        = $regKeyApp.InstallDate
                            Publisher          = $appPublisher
                            Is64BitApplication = $Is64BitApp
                        }
                    }
                }

                If ($name) {
                    ## Verify if there is a match with the application name(s) passed to the script
                    ForEach ($application in $Name) {
                        $applicationMatched = $false
                        #  Check for a contains application name match
                        If ($regKeyApp.DisplayName -match [regex]::Escape($application)) {
                            $applicationMatched = $true
                        }

                        If ($applicationMatched) {
                            $installedApplication += New-Object -TypeName 'PSObject' -Property @{
                                UninstallSubkey    = $regKeyApp.PSChildName
                                ProductCode        = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
                                DisplayName        = $appDisplayName
                                DisplayVersion     = $appDisplayVersion
                                UninstallString    = $regKeyApp.UninstallString
                                InstallSource      = $regKeyApp.InstallSource
                                InstallLocation    = $regKeyApp.InstallLocation
                                InstallDate        = $regKeyApp.InstallDate
                                Publisher          = $appPublisher
                                Is64BitApplication = $Is64BitApp
                            }
                        }
                    }
                }
            }
            Catch {
                Continue
            }
        }
        Write-Output -InputObject $installedApplication
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
    }
    Process {
        # Create the registry Key(s) if necessary.
        If (!(Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        # Check for existing registry setting
        $ExistingValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        If ($ExistingValue) {
            # Get current Value
            $CurrentValue = Get-ItemPropertyValue -Path $Path -Name $Name
            If ($Value -ne $CurrentValue) {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force | Out-Null
            }            
        }
        Else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value -Force | Out-Null
        }
        Start-Sleep -Milliseconds 500
    }
    End {
    }
}

#endregion Functions

# Convert escaped JSON strings to arrays
[array]$Shares = $Shares.replace('\', '') | ConvertFrom-Json  
[array]$StorageAccountNames = $StorageAccountNames.replace('\', '') | ConvertFrom-Json
[array]$StorageAccountKeys = $StorageAccountKeys.replace('\', '') | ConvertFrom-Json

#Convert CloudCache to Boolean
$CloudCache = [System.Convert]::ToBoolean($CloudCache)

[System.Collections.ArrayList]$ProfileContainerPaths = @()
[System.Collections.ArrayList]$CloudCacheProfileContainerPaths = @()
[System.Collections.ArrayList]$OfficeContainerPaths = @()
[System.Collections.ArrayList]$CloudCacheOfficeContainerPaths = @()

$ProfileShareName = $Shares[0]
if ($Shares.Count -gt 1) {
    $OfficeShareName = $Shares[1]
}
For ($i = 0; $i -lt $StorageAccountNames.Count; $i++) {
    $SAFQDN = "$($StorageAccountNames[$i]).file.$StorageAccountDNSSuffix"
    If ($StorageAccountKeys) {
        If ($StorageAccountKeys[$i]) {
            Start-Process -FilePath 'cmdkey.exe' -ArgumentList "/add:$SAFQDN /user:localhost\$($StorageAccountNames[$i]) /pass:$($StorageAccountKeys[$i])" -NoNewWindow -Wait
        }
    }
    If ($OfficeShareName) {
        $OfficeContainerPaths.Add("\\$SAFQDN\$OfficeShareName")
        $CloudCacheOfficeContainerPaths.Add("type=smb,connectionString=\\$SAFQDN\$OfficeShareName")
    }
    $ProfileContainerPaths.Add("\\$SAFQDN\$ProfileShareName")
    $CloudCacheProfileContainerPaths.Add("type=smb,connectionString=\\$SAFQDN\$ProfileShareName")
}

# from https://learn.microsoft.com/en-us/microsoftteams/new-teams-vdi-requirements-deploy#recommended-for-exclusion
# only specifying the folders that do not affect performance per article
$redirectionsXMLContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<FrxProfileFolderRedirection ExcludeCommonFolders="0">
<Excludes>
<Exclude Copy="0">AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs</Exclude>
<Exclude Copy="0">AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\PerfLog</Exclude>
<Exclude Copy="0">AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\EBWebView\WV2Profile_tfw\GPUCache</Exclude>
</Excludes>
<Includes>
</Includes>
</FrxProfileFolderRedirection>
'@

# Common Settings
$RegSettings = New-Object -TypeName 'System.Collections.ArrayList'

# Cleans up an invalid sessions to enable a successful sign-in: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#cleanupinvalidsessions
$RegSettings.Add([PSCustomObject]@{Name = 'CleanupInvalidSessions'; Path = 'HKLM:\SOFTWARE\FSLogix\Apps'; PropertyType = 'DWord'; Value = 1 })
# Enables Fslogix profile containers: https://learn.microsoft.com/fslogix/profile-container-configuration-reference#enabled
$RegSettings.Add([PSCustomObject]@{Name = 'Enabled'; Path = 'HKLM:\SOFTWARE\Fslogix\Profiles'; PropertyType = 'DWord'; Value = 1 })
# Deletes a local profile if it exists and matches the profile being loaded from VHD: https://learn.microsoft.com/fslogix/profile-container-configuration-reference#deletelocalprofilewhenvhdshouldapply
$RegSettings.Add([PSCustomObject]@{
        Name         = 'DeleteLocalProfileWhenVHDShouldApply'
        Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value        = 1
    })
# The folder created in the Fslogix fileshare will begin with the username instead of the SID: https://learn.microsoft.com/fslogix/profile-container-configuration-reference#flipflopprofiledirectoryname
$RegSettings.Add([PSCustomObject]@{
        Name         = 'FlipFlopProfileDirectoryName'
        Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value        = 1
    })
# Prevent Login with a failure: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#preventloginwithfailure
$RegSettings.Add([PSCustomObject]@{
        Name         = 'PreventLoginWithFailure'
        Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value        = 1
    })
# Prevent Login with a temporary profile: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#preventloginwithtempprofile
$RegSettings.Add([PSCustomObject]@{
        Name         = 'PreventLoginWithTempProfile'
        Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value        = 1
    })
# Specifies the number of seconds to wait between retries when attempting to reattach the VHD(x) container if it's disconnected unexpectedly: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=profiles#reattachintervalseconds
$RegSettings.Add([PSCustomObject]@{
        Name         = 'ReAttachIntervalSeconds'
        Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value        = 15
    })
# Specifies the number of times the system should attempt to reattach the VHD(x) container if it's disconnected unexpectedly: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=profiles#reattachretrycount
$RegSettings.Add([PSCustomObject]@{
        Name         = 'ReAttachRetryCount'
        Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value        = 3
    })
# Specifies the maximum size of the user's container in megabytes. Newly created VHD(x) containers are of this size: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=profiles#sizeinmbs
$RegSettings.Add([PSCustomObject]@{
        Name         = 'SizeInMBs'
        Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value        = 30000
    })
# Specifies the file extension for the profile containers: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=profiles#volumetype
$RegSettings.Add([PSCustomObject]@{
        Name         = 'VolumeType'
        Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'String'
        Value        = 'VHDX'
    })
# Attach the users VHD(x) as the computer: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#accessnetworkascomputerobject
$RegSettings.Add([PSCustomObject]@{
        Name         = 'AccessNetworkAsComputerObject'
        Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value        = 1
    }
)

If ($CloudCache -eq $True) {    
    $RegSettings.Add(
        # List of file system locations to search for the user's profile VHD(X) file: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=ccd#ccdlocations
        [PSCustomObject]@{
            Name         = 'CCDLocations'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'MultiString'
            Value        = $CloudCacheProfileContainerPaths
        })
    # Clear the cloud cache on logoff: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=ccd#clearcacheonlogoff
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'ClearCacheOnLogoff'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 1
        }
    )
}
Else {
    $RegSettings.Add(
        # List of file system locations to search for the user's profile VHD(X) file: https://learn.microsoft.com/fslogix/profile-container-configuration-reference#vhdlocations
        [PSCustomObject]@{
            Name         = 'VHDLocations'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'MultiString'
            Value        = $ProfileContainerPaths
        }
    )
}

If ($OfficeContainerPaths) {    
    $RegSettings.Add( 
        # Enables Fslogix office containers: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#enabled-1       
        [PSCustomObject]@{
            Name         = 'Enabled'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 1
        })
    # The folder created in the Fslogix fileshare will begin with the username instead of the SID: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#flipflopprofiledirectoryname-1
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'FlipFlopProfileDirectoryName'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 1
        })
    # Specifies the number of retries attempted when a VHD(x) file is locked: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#lockedretrycount
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'LockedRetryCount'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 3
        })
    # Specifies the number of seconds to wait between retries: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#lockedretryinterval
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'LockedRetryInterval'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 15
        })
    # Prevent Login with a failure: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#preventloginwithfailure-1
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'PreventLoginWithFailure'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 1
        })
    # Prevent Login with Temporary Profile: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#preventloginwithtempprofile-1
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'PreventLoginWithTempProfile'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 15
        })        
    # Specifies the number of seconds to wait between retries when attempting to reattach the VHD(x) container if it's disconnected unexpectedly: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#reattachintervalseconds
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'ReAttachIntervalSeconds'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 15
        })
    # Specifies the number of times the system should attempt to reattach the VHD(x) container if it's disconnected unexpectedly: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#reattachretrycount
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'ReAttachRetryCount'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 3
        })
    # Specifies the maximum size of the user's container in megabytes: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#sizeinmbs
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'SizeInMBs'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 30000
        })
    # Specifies the type of container: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#volumetype
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'VolumeType'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'String'
            Value        = 'VHDX'
        })
    # Attach the users VHD(x) as the computer: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#accessnetworkascomputerobject-1
    $RegSettings.Add([PSCustomObject]@{
            Name         = 'AccessNetworkAsComputerObject'
            Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value        = 1
        }
    )
    If ($CloudCache -eq $True) {
        $RegSettings.Add(
            # List of file system locations to search for the user's profile VHD(X) file: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=ccd#ccdlocations
            [PSCustomObject]@{
                Name         = 'CCDLocations'
                Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
                PropertyType = 'MultiString'
                Value        = $CloudCacheOfficeContainerPaths
            })
        # Clear the cloud cache on logoff: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=ccd#clearcacheonlogoff
        $RegSettings.Add([PSCustomObject]@{
                Name         = 'ClearCacheOnLogoff'
                Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
                PropertyType = 'DWord'
                Value        = 1
            }
        )
    }
    Else {
        $RegSettings.Add(
            # List of file system locations to search for the user's profile VHD(X) file: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#vhdlocations-1
            [PSCustomObject]@{
                Name         = 'VHDLocations'
                Path         = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
                PropertyType = 'MultiString'
                Value        = $OfficeContainerPaths
            }
        )
    }       
}

If (Get-InstalledApplication 'Teams') {
    $customRedirFolder = "$env:ProgramData\FSLogix_CustomRedirections"
    If (-not (Test-Path $customRedirFolder )) {
        New-Item -Path $customRedirFolder -ItemType Directory -Force
    }
    $customRedirFilePath = "$customRedirFolder\redirections.xml"
    $redirectionsXMLContent | Out-File -FilePath $customRedirFilePath -Encoding unicode
    # Path where FSLogix looks for the redirections.xml file to copy from and into the user's profile: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#redirxmlsourcefolder
    $RegSettings.Add(
        [PSCustomObject]@{
            Name         = 'RedirXMLSourceFolder'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'String'
            Value        = $customRedirFolder
        }
    )
}

ForEach ($Setting in $RegSettings) {
    Set-RegistryValue -Name $Setting.Name -Path $Setting.Path -PropertyType $Setting.PropertyType -Value $Setting.Value -Verbose
}
$LocalAdministrator = (Get-LocalUser | Where-Object { $_.SID -like '*-500' }).Name
$LocalGroups = 'FSLogix Profile Exclude List', 'FSLogix ODFC Exclude List'
ForEach ($Group in $LocalGroups) {
    If (-not (Get-LocalGroupMember -Group $Group | Where-Object { $_.Name -like "*$LocalAdministrator" })) {
        Add-LocalGroupMember -Group $Group -Member $LocalAdministrator
    }
}