[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)]
    [Hashtable]$DynParameters
)
[string]$Script:LogDir = "C:\Windows\Logs\Configuration"
[string]$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

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
    $content = "[$date]`t$category`t`t$message" 
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
        Write-Log -message "${CmdletName}: Gathering Registry text files for LGPO from '$InputDir'"
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

Function Get-InstalledApplication {
    <#
    .SYNOPSIS
        Retrieves information about installed applications.
    .DESCRIPTION
        Retrieves information about installed applications by querying the registry. You can specify an application name, a product code, or both.
        Returns information about application publisher, name & version, product code, uninstall string, install source, location, date, and application architecture.
    .PARAMETER Name
        The name of the application to retrieve information for. Performs a contains match on the application display name by default.
    .PARAMETER Exact
        Specifies that the named application must be matched using the exact name.
    .PARAMETER WildCard
        Specifies that the named application must be matched using a wildcard search.
    .PARAMETER RegEx
        Specifies that the named application must be matched using a regular expression search.
    .PARAMETER ProductCode
        The product code of the application to retrieve information for.
    .PARAMETER IncludeUpdatesAndHotfixes
        Include matches against updates and hotfixes in results.
    .EXAMPLE
        Get-InstalledApplication -Name 'Adobe Flash'
    .EXAMPLE
        Get-InstalledApplication -ProductCode '{1AD147D0-BE0E-3D6C-AC11-64F6DC4163F1}'
    .NOTES
    .LINK
        http://psappdeploytoolkit.com
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string[]]$Name,
        [Parameter(Mandatory=$false)]
        [switch]$Exact = $false,
        [Parameter(Mandatory=$false)]
        [switch]$WildCard = $false,
        [Parameter(Mandatory=$false)]
        [switch]$RegEx = $false,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$ProductCode,
        [Parameter(Mandatory=$false)]
        [switch]$IncludeUpdatesAndHotfixes
    )

    Begin {
        [string[]]$regKeyApplications = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
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
                    Catch{
                        Continue
                    }
                }
            }
        }

        $UpdatesSkippedCounter = 0
        ## Create a custom object with the desired properties for the installed applications and sanitize property details
        [psobject[]]$installedApplication = @()
        ForEach ($regKeyApp in $regKeyApplication) {
            Try {
                [string]$appDisplayName = ''
                [string]$appDisplayVersion = ''
                [string]$appPublisher = ''

                ## Bypass any updates or hotfixes
                If ((-not $IncludeUpdatesAndHotfixes) -and (($regKeyApp.DisplayName -match '(?i)kb\d+') -or ($regKeyApp.DisplayName -match 'Cumulative Update') -or ($regKeyApp.DisplayName -match 'Security Update') -or ($regKeyApp.DisplayName -match 'Hotfix'))) {
                    $UpdatesSkippedCounter += 1
                    Continue
                }

                ## Remove any control characters which may interfere with logging and creating file path names from these variables
                $appDisplayName = $regKeyApp.DisplayName -replace '[^\u001F-\u007F]',''
                $appDisplayVersion = $regKeyApp.DisplayVersion -replace '[^\u001F-\u007F]',''
                $appPublisher = $regKeyApp.Publisher -replace '[^\u001F-\u007F]',''


                ## Determine if application is a 64-bit application
                [boolean]$Is64BitApp = If (($is64Bit) -and ($regKeyApp.PSPath -notmatch '^Microsoft\.PowerShell\.Core\\Registry::HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node')) { $true } Else { $false }

                If ($ProductCode) {
                    ## Verify if there is a match with the product code passed to the script
                    If ($regKeyApp.PSChildName -match [regex]::Escape($productCode)) {
                        $installedApplication += New-Object -TypeName 'PSObject' -Property @{
                            UninstallSubkey = $regKeyApp.PSChildName
                            ProductCode = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
                            DisplayName = $appDisplayName
                            DisplayVersion = $appDisplayVersion
                            UninstallString = $regKeyApp.UninstallString
                            InstallSource = $regKeyApp.InstallSource
                            InstallLocation = $regKeyApp.InstallLocation
                            InstallDate = $regKeyApp.InstallDate
                            Publisher = $appPublisher
                            Is64BitApplication = $Is64BitApp
                        }
                    }
                }

                If ($name) {
                    ## Verify if there is a match with the application name(s) passed to the script
                    ForEach ($application in $Name) {
                        $applicationMatched = $false
                        If ($exact) {
                            #  Check for an exact application name match
                            If ($regKeyApp.DisplayName -eq $application) {
                                $applicationMatched = $true
                            }
                        }
                        ElseIf ($WildCard) {
                            #  Check for wildcard application name match
                            If ($regKeyApp.DisplayName -like $application) {
                                $applicationMatched = $true
                            }
                        }
                        ElseIf ($RegEx) {
                            #  Check for a regex application name match
                            If ($regKeyApp.DisplayName -match $application) {
                                $applicationMatched = $true
                            }
                        }
                        #  Check for a contains application name match
                        ElseIf ($regKeyApp.DisplayName -match [regex]::Escape($application)) {
                            $applicationMatched = $true
                        }

                        If ($applicationMatched) {
                            $installedApplication += New-Object -TypeName 'PSObject' -Property @{
                                UninstallSubkey = $regKeyApp.PSChildName
                                ProductCode = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
                                DisplayName = $appDisplayName
                                DisplayVersion = $appDisplayVersion
                                UninstallString = $regKeyApp.UninstallString
                                InstallSource = $regKeyApp.InstallSource
                                InstallLocation = $regKeyApp.InstallLocation
                                InstallDate = $regKeyApp.InstallDate
                                Publisher = $appPublisher
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
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        $LogOutputValue = "Path: $Path, Name: $Name, PropertyType: $PropertyType, Value: $Value"
        # Create the registry Key(s) if necessary.
        If(!(Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        # Check for existing registry setting
        $ExistingValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        If ($ExistingValue) {
            # Get current Value
            $CurrentValue = Get-ItemPropertyValue -Path $Path -Name $Name
            Write-Log -message "${CmdletName}: Existing Registry Value Found - Path: $Path, Name: $Name, PropertyType: $PropertyType, Value: $CurrentValue"
            If ($Value -ne $CurrentValue) {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force | Out-Null
                Write-Log -message "${CmdletName}: Updated registry setting: $LogOutputValue"
            } Else {
                Write-Log -message "${CmdletName}: Registry Setting exists with correct value: $LogOutputValue"
            }
        } Else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value -Force | Out-Null
            Write-Log -message "${CmdletName}: Added registry setting: $LogOutputValue"
        }
        Start-Sleep -Milliseconds 500
    }
    End {
    }
}

#endregion Functions

New-Log -Path $Script:LogDir
Write-Log -message "Starting '$PSCommandPath'."
$TempDir = Join-Path -Path $env:Temp -ChildPath $Script:Name
If (Test-Path -Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force }
New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

$FsLogixKeys = $DynParameters.FSLogix
$IdentityProvider = $FSLogixKeys.idp
$CloudCache = $FsLogixKeys.cloudCache
$StorageSolution = $FSLogixKeys.storageSolution
Write-Log -message '* Begin Script Parameters *'
Write-Log -message 'Started Script with the following Dynamic Parameters:'
Write-Log -message "IdentityProvider = $IdentityProvider"
Write-Log -message "StorageSolution = $StorageSolution"
Write-Log -message "CloudCache = $CloudCache"

switch($StorageSolution) {
    'AzureNetAppFiles' {
        [array]$NetAppFileShares = $FSLogix.NetAppFileShares
        Write-Log -message 'NetAppFileShares ='
        ForEach($Share in $NetAppFileShares) { Write-Log -message " $Share" }
        [array]$OfficeContainerPaths += "\\$($NetAppFileShares[1])"
        [array]$ProfileContainerPaths += "\\$($NetAppFileShares[0])"
        [array]$CloudCacheOfficeContainerPaths += "type=smb,connectionString=\\$($NetAppFileShares[1])"
        [array]$CloudCacheProfileContainerPaths += "type=smb,connectionString=\\$($NetAppFileShares[0])"
        Write-Log -message '* End Script Parameters *'
    }
    Default {
        [array]$StorageAccountNames = $FSLogixKeys.saNames
        Write-Log -message 'Azure Storage Account Names ='
        ForEach($sa in $StorageAccountNames) { Write-Log -message " $sa" }
        [array]$StorageAccountKeys = $FSLogixKeys.saKeys
        if($null -ne $StorageAccountKeys) { Write-Log -message "$($StorageAccountKeys.Count) storage account keys provided." }
        $StorageAccountSuffix = $FSLogixKeys.saSuffix
        Write-Log -message "Storage Account Suffix = $StorageAccountSuffix"        
        $ProfileShareName = $FSLogixKeys.shareNames[0]
        $OfficeShareName = $FSLogixKeys.shareNames[1]
        If ($null -ne $OfficeShareName) { Write-Log -message "Office Container Share Name = $OfficeShareName" }
        Write-Log -message "Profile Container Share Name = $ProfileShareName"
        Write-Log -message '* End Script Parameters *'
        Write-Log -message '* Calculated Values *'
        For ($i = 0; $i -lt $StorageAccountNames.Count; $i++) {
            Write-Log -message "Storage Account: $($StorageAccountNames[$i])"
            $SAFQDN = "$($StorageAccountNames[$i]).file.$StorageAccountSuffix"
            Write-Log -message " FQDN: $SAFQDN"
            If ($StorageAccountKeys[$i] -and $IdentityProvider -eq 'AAD') {
                Write-Log -message ' Storage Key Provided, stored securely in credential manager.'
                Start-Process -FilePath 'cmdkey.exe' -ArgumentList "/add:$SAFQDN /user:localhost\$($StorageAccountNames[$i]) /pass:$($StorageAccountKeys[$i])" -NoNewWindow -Wait
            }
            If ($OfficeShareName) {
                [array]$OfficeContainerPaths += "\\$SAFQDN\$OfficeShareName"
                [array]$CloudCacheOfficeContainerPaths += "type=smb,connectionString=\\$SAFQDN\$OfficeShareName"
                Write-Log -message " Office Container Share Path: \\$SAFQDN\$OfficeShareName"
            }
            If ($ProfileShareName) {
                [array]$ProfileContainerPaths += "\\$SAFQDN\$ProfileShareName"
                [array]$CloudCacheProfileContainerPaths += "type=smb,connectionString=\\$SAFQDN\$ProfileShareName"
                Write-Log -message " Profile Container Share Path: \\$SAFQDN\$ProfileShareName"
            }
        }
        Write-Log -message '* End Calculated Values *'
    }
}

[array]$defenderShareExclusionPaths = $($OfficeContainerPaths; $ProfileContainerPaths)

[array]$Settings = @()

$redirectionsXMLContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<FrxProfileFolderRedirection ExcludeCommonFolders="0">
<Excludes>
<Exclude Copy="0">AppData\Roaming\Microsoft\Teams\media-stack</Exclude>
<Exclude Copy="0">AppData\Local\Microsoft\Teams\meeting-addin\Cache</Exclude>
</Excludes>
<Includes>
</Includes>
</FrxProfileFolderRedirection>
'@

# Common Settings

 $Settings += @(

     # Cleans up an invalid sessions to enable a successful sign-in: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#cleanupinvalidsessions
     [PSCustomObject]@{
        Name = 'CleanupInvalidSessions'
        Path = 'HKLM:\SOFTWARE\FSLogix\Apps'
        PropertyType = 'DWord'
        Value = 1
    },

    # Enables Fslogix profile containers: https://learn.microsoft.com/fslogix/profile-container-configuration-reference#enabled
    [PSCustomObject]@{
        Name = 'Enabled'
        Path = 'HKLM:\SOFTWARE\Fslogix\Profiles'
        PropertyType = 'DWord'
        Value = 1
    },

    # Deletes a local profile if it exists and matches the profile being loaded from VHD: https://learn.microsoft.com/fslogix/profile-container-configuration-reference#deletelocalprofilewhenvhdshouldapply
    [PSCustomObject]@{
        Name = 'DeleteLocalProfileWhenVHDShouldApply'
        Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value = 1
    },

    # The folder created in the Fslogix fileshare will begin with the username instead of the SID: https://learn.microsoft.com/fslogix/profile-container-configuration-reference#flipflopprofiledirectoryname
    [PSCustomObject]@{
        Name = 'FlipFlopProfileDirectoryName'
        Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value = 1
    },

    # Prevent Login with a failure: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#preventloginwithfailure
    [PSCustomObject]@{
        Name = 'PreventLoginWithFailure'
        Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value = 1
    },

    # Prevent Login with a temporary profile: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#preventloginwithtempprofile
    [PSCustomObject]@{
        Name = 'PreventLoginWithTempProfile'
        Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value = 1
    },

    # Specifies the number of seconds to wait between retries when attempting to reattach the VHD(x) container if it's disconnected unexpectedly: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=profiles#reattachintervalseconds
    [PSCustomObject]@{
        Name = 'ReAttachIntervalSeconds'
        Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value = 15
    },

    # Specifies the number of times the system should attempt to reattach the VHD(x) container if it's disconnected unexpectedly: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=profiles#reattachretrycount
    [PSCustomObject]@{
        Name = 'ReAttachRetryCount'
        Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value = 3
    },

    # Specifies the maximum size of the user's container in megabytes. Newly created VHD(x) containers are of this size: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=profiles#sizeinmbs
    [PSCustomObject]@{
        Name = 'SizeInMBs'
        Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'DWord'
        Value = 30000
    },

    # Specifies the file extension for the profile containers: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=profiles#volumetype
    [PSCustomObject]@{
        Name = 'VolumeType'
        Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        PropertyType = 'String'
        Value = 'VHDX'
    }
)

If ($IdentityProvider -eq 'AAD') {
    $Settngs += @(
        # Attach the users VHD(x) as the computer: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#accessnetworkascomputerobject
        [PSCustomObject]@{
            Name = 'AccessNetworkAsComputerObject'
            Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value = 1
        }
    )
}

If ($CloudCache) {
    $Settings += @(
        # List of file system locations to search for the user's profile VHD(X) file: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=ccd#ccdlocations
        [PSCustomObject]@{
            Name = 'CCDLocations'
            Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'MultiString'
            Value = $CloudCacheProfileContainerPaths
        },

        # Clear the cloud cache on logoff: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=ccd#clearcacheonlogoff
        [PSCustomObject]@{
            Name = 'ClearCacheOnLogoff'
            Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value = 1
        }
    )
} Else {
    $Settings += @(
        # List of file system locations to search for the user's profile VHD(X) file: https://learn.microsoft.com/fslogix/profile-container-configuration-reference#vhdlocations
        [PSCustomObject]@{
            Name = 'VHDLocations'
            Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'MultiString'
            Value = $ProfileContainerPaths
        }
    )
}

If ($OfficeContainerPaths) {
    $Settings += @(

        # Enables Fslogix office containers: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#enabled-1
        [PSCustomObject]@{
            Name = 'Enabled'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value = 1
        },

        # The folder created in the Fslogix fileshare will begin with the username instead of the SID: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#flipflopprofiledirectoryname-1
        [PSCustomObject]@{
            Name = 'FlipFlopProfileDirectoryName'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value = 1
        },

        # Specifies the number of retries attempted when a VHD(x) file is locked: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#lockedretrycount
        [PSCustomObject]@{
            Name = 'LockedRetryCount'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value = 3
        },

        # Specifies the number of seconds to wait between retries: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#lockedretryinterval
        [PSCustomObject]@{
            Name = 'LockedRetryInterval'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value = 15
        },

        # Prevent Login with a failure: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#preventloginwithfailure-1
        [PSCustomObject]@{
            Name = 'PreventLoginWithFailure'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value = 1
        },

        # Prevent Login with Temporary Profile: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#preventloginwithtempprofile-1
        [PSCustomObject]@{
            Name = 'PreventLoginWithTempProfile'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value = 15
        },
        
        # Specifies the number of seconds to wait between retries when attempting to reattach the VHD(x) container if it's disconnected unexpectedly: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#reattachintervalseconds
        [PSCustomObject]@{
            Name = 'ReAttachIntervalSeconds'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value = 15
        },

        # Specifies the number of times the system should attempt to reattach the VHD(x) container if it's disconnected unexpectedly: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#reattachretrycount
        [PSCustomObject]@{
            Name = 'ReAttachRetryCount'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value = 3
        },

        # Specifies the maximum size of the user's container in megabytes: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#sizeinmbs
        [PSCustomObject]@{
            Name = 'SizeInMBs'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'DWord'
            Value = 30000
        },

        # Specifies the type of container: https://learn.microsoft.com/fslogix/reference-configuration-settings?tabs=odfc#volumetype
        [PSCustomObject]@{
            Name = 'VolumeType'
            Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
            PropertyType = 'String'
            Value = 'VHDX'
        }
    )

    If ($IdentityProvider -eq 'AAD') {
        $Settings += @(
            # Attach the users VHD(x) as the computer: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#accessnetworkascomputerobject-1
            [PSCustomObject]@{
                Name = 'AccessNetworkAsComputerObject'
                Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
                PropertyType = 'DWord'
                Value = 1
            }
        )
    }

    If ($CloudCache) {
        $Settings += @(
            # List of file system locations to search for the user's profile VHD(X) file: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=ccd#ccdlocations
            [PSCustomObject]@{
                Name = 'CCDLocations'
                Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
                PropertyType = 'MultiString'
                Value = $CloudCacheOfficeContainerPaths
            },

            # Clear the cloud cache on logoff: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=ccd#clearcacheonlogoff
            [PSCustomObject]@{
                Name = 'ClearCacheOnLogoff'
                Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
                PropertyType = 'DWord'
                Value = 1
            }
        )
    } Else {
        $Settings += @(
            # List of file system locations to search for the user's profile VHD(X) file: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=odfc#vhdlocations-1
            [PSCustomObject]@{
                Name = 'VHDLocations'
                Path = 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC'
                PropertyType = 'MultiString'
                Value = $OfficeContainerPaths
            }
        )
    }       
}

If ($IdentityProvider -eq 'AADKERB') {
    # Support for Azure Files Azure AD Kerberos Authentication for Hybrid Identities
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath 'SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters' -RegistryValue 'CloudKerberosTicketRetrievalEnabled' -RegistryData 1 -RegistryType DWORD -outfileprefix $appName -Verbose
    $Settings += @(        
        [PSCustomObject]@{
            Name = 'LoadCredKeyFromProfile'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\AzureADAccount'
            PropertyType = 'DWord'
            Value = 1
        }
    )
}
    
If (Get-InstalledApplication 'Teams') {
    $customRedirFolder = "$env:ProgramFiles\FSLogix\CustomRedirections"
    If (-not (Test-Path $customRedirFolder )) {
        New-Item -Path $customRedirFolder -ItemType Directory -Force
    }
    $customRedirFilePath = "$customRedirFolder\redirections.xml"
    $redirectionsXMLContent | Out-File -FilePath $customRedirFilePath -Encoding unicode
    # Path where FSLogix looks for the redirections.xml file to copy from and into the user's profile: https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles#redirxmlsourcefolder
    $Settings += @(
        [PSCustomObject]@{
            Name = 'RedirXMLSourceFolder'
            Path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'String'
            Value = $customRedirFolder
        }
    )
}

If (!(Test-Path -Path "$env:SystemRoot\System32\lgpo.exe")) {
    Try {
        $fileLGPO = (Get-ChildItem -Path $PSScriptRoot -File -Filter 'lgpo.exe' -Recurse).FullName
        If (-not $fileLGPO) {
            $urlLGPO = 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip'
            $outputDir = $TempDir
            $fileLGPODownload = Get-InternetFile -Url $urlLGPO -OutputDirectory $outputDir -ErrorAction SilentlyContinue
            Expand-Archive -Path $fileLGPODownload -DestinationPath $outputDir -Force
            Remove-Item $fileLGPODownload -Force
            $fileLGPO = (Get-ChildItem -Path $outputDir -file -Filter 'lgpo.exe' -Recurse)[0].FullName
        }
        Write-Log -category Info -Message "Copying `"$fileLGPO`" to System32"
        Copy-Item -Path $fileLGPO -Destination "$env:SystemRoot\System32" -Force
    } Catch {
        Write-Log -category Warning -Message "LGPO.exe could not be found or downloaded. Unable to apply Defender Exclusions via lgpo."
    }

}

If (Test-Path -Path "$env:SytemRoot\System32\lgpo.exe") {
    $appName = "Windows_Defender"
    $DefenderExclusionsRegKeyPath = 'SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions'
    #Defender Path Exclusions
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $defenderExclusionsRegKeyPath -RegistryValue 'Exclusions_Paths' -RegistryType DWord -RegistryData 1 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $defenderExclusionsRegKeyPath -RegistryValue 'Exclusions_Processes' -RegistryType DWord -RegistryData 1 -outfileprefix $appName -Verbose
    $regKey = "$defenderExclusionsRegKeyPath\Paths"
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramFiles%\FSLogix\Apps\frxdrv.sys' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramFiles%\FSLogix\Apps\frxdrvvt.sys' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramFiles%\FSLogix\Apps\frxccd.sys' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%TEMP\*.VHD' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%TEMP\*.VHDX' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%WINDIR%\TEMP\*.VHD' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%WINDIR%\TEMP\*.VHDX' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
    For($i=0,$i -lt $defenderShareExclusionPaths.Length,$i++) {
        $value = "$($defenderShareExclusionPaths[$i])\*\*.vhdx"
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue $value -RegistryType String -RegistryData '' -outfileprefix $appName -Verbose
    }
    if ($CloudCache) {
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramData%\FSLogix\Cache\*.VHD' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramData%\FSLogix\Cache\*.VHDX' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramData%\FSLogix\Proxy\*.VHD' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
        Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramData%\FSLogix\Proxy\*.VHDX' -RegistryType String -RegistryData 0 -outfileprefix $appName -Verbose
    }
    $regKey = "$defenderExclusionsRegKeyPath\Processes"
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramFiles%\FSLogix\Apps\frxccd.exe' -RegistryType String -RegistryData '' -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramFiles%\FSLogix\Apps\frxccds.exe' -RegistryType String -RegistryData '' -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope Computer -RegistryKeyPath $regKey -RegistryValue '%ProgramFiles%\FSLogix\Apps\frxsvc.exe' -RegistryType String -RegistryData '' -outfileprefix $appName -Verbose

    Write-Log -message 'Running function to update Local Group Policy Object with LGPO.'
    Invoke-LGPO -Verbose
}
Write-Log -message "Updating Registry Settings."
ForEach($Setting in $Settings) {
    Set-RegistryValue -Name $Setting.Name -Path $Setting.Path -PropertyType $Setting.PropertyType -Value $Setting.Value -Verbose
}

Write-Log -message "Adding local Administrator account to Exclude List groups to allow emergency troubleshooting."
$LocalAdministrator = (Get-LocalUser | Where-Object {$_.SID -like '*-500'}).Name
$LocalGroups = 'FSLogix Profile Exclude List','FSLogix ODFC Exclude List'
ForEach ($Group in $LocalGroups) {
    If (-not (Get-LocalGroupMember -Group $Group | Where-Object {$_.Name -like "*$LocalAdministrator"})) {
        Add-LocalGroupMember -Group $Group -Member $LocalAdministrator
    }
}
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Log -message "Ending '$PSCommandPath'."