<#

#>

[CmdletBinding()]
param (
    # The App Name to pass to the WUA API as the calling application.
    [Parameter()]
    [String]$AppName = "Windows Update API Script",
    # The search criteria to be used.
    [Parameter()]
    [String]$Criteria = "IsInstalled=0 and Type='Software' and IsHidden=0",
    # Don't prompt the user for various actions.
    [Parameter()]
    [Boolean]$Automate = $true,
    # Display all applicable updates, even those superseded by newer updates.
    [Parameter()]
    [Boolean]$IgnoreSupersedence,
    # Path to WSUSSCN2.cab file that should be used for an offline search.
    [Parameter()]
    [string]$Offline,
    # Default service (WSUS if machine is configured to use it, or MU if opted in, or WU otherwise.)
    [Parameter()]
    [string]$Service = 'MU',
    # Hide updates found by the scan. Hidden updates will not normally be installed by automatic updates.
    [Parameter()]
    [boolean]$Hide = $false,
    # Unhide any hidden updates found by the scan.
    [Parameter()]
    [boolean]$Show = $false,
    # Do not download any updates that the scan detects.
    [Parameter()]
    [switch]$NoDownload,
    # Do not install anything that the scan detects.
    [Parameter()]
    [switch]$NoInstall,
    # Show Details
    [Parameter()]
    [switch]$ShowDetails,
    # Output information about the child updates in the bundle.
    [Parameter()]
    [switch]$ShowBundle,
    # Restart the computer if necessary to complete the installation.
    [Parameter()]
    [boolean]$RebootToComplete
)

Function Get-InstallationResultText {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int] $Result
    )
    Switch ($Result) {
        2 {$Text = "Succeed"}
        3 {$Text = "Succeed with errors"}
        4 {$Text = "Failed"}
        5 {$Text = "Cancelled"}
        Else {$Text = "Unexpected ($result)"}
    } 
    Return $Text
}

Function Get-DeploymentActionText {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]$Action
    )
    Switch ($Action) {
        0 {$Text = "None (Inherit)"}
        1 {$Text = "Installation"}
        2 {$Text = "Uninstallation"}
        3 {$Text = "Detection"}
        4 {$Text = "Optional Installation"}
        5 {$Text = "Unexpected ($Action)"}
    }
    Return $Text
}

function Get-UpdateDescription {
    [CmdletBinding()]
    param (
        [Parameter()]
        $Update
    )
    [String]$Description = $null
    [string]$Description = "$($Update.Title) {$($update.Identity.UpdateID).$($update.IdentityRevisionNumber)}"
    If ($Update.IsHidden) {
        $Description = "$($Description) (hidden)"
    }
    If ($Script:ShowDetails) {
        If($update.KBArticleIDs.Count -gt 0) {
            $Description = "$($Description)  ("
            For ($i=0; $i -lt $($Update.KBArticleIDs.Count); $i++) {
                If ($i -gt 0) {
                    $Description = "$($Description), "
                }
                $Description = "$($Description)KB$($update.KBArticleIDs.Item[$i])"
            }
            $Description = "$($Description))"
        }
        $Description = "$($Description)  Categories: "
        For ($i=0; $i -lt $Update.Categories.Count; $i++) {
            $Category = $($Update.Categories.Item[$i])
            If ($i -gt 0) {
                $Description = "$($Description),"
            }
            $Description = "$($Description) $($Category.Name) {$($Category.CategoryID)}"
        }
        $Description = "$($Description) Deployment action: ($(Get-DeploymentActionText -Action $($Update.DeploymentAction))"
    }
    Return $Description
}

$isAutomated = $Automate

Switch($Service.ToUpper()) {
    'WU'    {$ServerSelection = 2}
    'MU'    {$ServerSelection = 3; $ServiceId = "7971f918-a847-4430-9279-4a52d1efe18d"}
    'WSUS'  {$ServerSelection = 1}
    'DCAT'  {$ServerSelection = 3; $ServiceId = "855E8A7C-ECB4-4CA3-B045-1DFA50104289"}
    'STORE' {$serverSelection = 3; $ServiceId = "117cab2d-82b1-4b5a-a08c-4d62dbee7782"}
    Else    {$ServerSelection = 3; $ServiceId = $Service}
}

[string]$StringInput = $null
[int]$ReturnValue = 0

If ($Offline) {
    $UpdateServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    $OfflineService = $UpdateServiceManager.AddScanPackageService($appName, $Offline, 0)
    $ServerSelection = 3
    $ServiceId = $OfflineService.ServiceID
    Write-Output "Registered offline scan cab, service ID: $ServiceID"
}

If ($Service -eq 'MU') {
    $UpdateServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    $UpdateServiceManager.ClientApplicationID = $AppName
    $UpdateServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")
}

$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$updateSession.ClientApplicationID = $AppName
    
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
$UpdateSearcher.ServerSelection = $ServerSelection
If ($ServerSelection -eq 3) {
    $UpdateSearcher.ServiceId = $ServiceId
}
If ($IgnoreSupersedence) {
    $UpdateSearcher.IncludePotentiallySupersededUpdates = $true
}
Write-Output "Searching for Updates..."

$SearchResult = $UpdateSearcher.Search($Criteria)
If ($SearchResult.Updates.Count -eq 0) {
    Write-Output "There are no applicable updates."
} Else {
    Write-Output "List of applicable items found for this computer:"

    For ($i=0; $i -lt $SearchResult.Updates.Count; $i++) {
        $Update = $SearchResult.Updates.Item[$i]
        Write-Output "$($i + 1)  > $(Get-UpdateDescription -Update $Update)"
        If ($ShowBundle) {
            For ($b=0; $b -lt $Update.BundledUpdates.Count; $b++) {
                Write-Output "$($i + 1)  >  $($b + 1)  > $(Get-UpdateDescription -Update $($Update.BundledUpdates.Item[$b]))"
            }
        }
    }

    $AtLeastOneAdded = $false
    $ExclusiveAdded = $false
    
    If ($NoDownload -and $null -eq $hide -and $null -eq $Show) {
        Write-Output "Skipping downloads as requested."
    } Else {
        $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
        Write-Output "Checking search results:"
        For ($i=0; $i -lt $SearchResult.Updates.Count; $i++) {
            $Update = $SearchResult.Updates.Item[$i]
            $Description = Get-UpdateDescription -Update $Update
            $AddThisUpdate = $false
            If ($Hide -and -not ($($Update.IsHidden))) {
                $HideUpdate = $true
                If (-not ($isAutomated)) {
                    $StringInput = Read-Host -Prompt "$($i+1) > : '$($Description)' is now shown; Do you want to hide it? ([Y]/N)"
                    If ($StringInput.toLower -eq 'n') {
                        $HideUpdate = $false
                    }
                }                   
                If ($HideUpdate = $true) {
                    Write-Output "Hiding update"
                    $Update.IsHidden = $true
                }
            } ElseIf ($Show -and $Update.IsHidden) {
                $ShowUpdate = $true
                If (-not $isAutomated) {
                    $StringInput = Read-Host -Prompt "$($i+1) > : '$($Description)' is now hidden; Do you want to show it? ([Y]/N)"
                    If ($StringInput.toLower -eq 'n') {
                        $ShowUpdate = $false
                    }
                }
                If ($ShowUpdate = $true) {       
                    Write-Output "Showing update"
                    $Update.IsHidden = $false
                }                
            }

            If ($ExclusiveAdded) {
                Write-Output "$($i + 1) > skipping: '$($Description)' because an exclusive update has already been selected."
            } ElseIf (-not $NoDownload) {
                $PropertyTest = $false
                $ErrorActionPreference = 'SilentlyContinue'
                $PropertyTest = $Update.InstallationBehavior.CanRequestUserInput
                $ErrorActionPreference = 'Stop'
                If ($PropertyTest = $false) {
                    If ($isAutomated) {
                        Write-Output "$($i+1) > skipping: '$($Description)' because it requires user input."
                    } Else {
                        $PropertyTest = $true
                        $ErrorActionPreference = 'SilentlyContinue'
                        $PropertyTest = $Update.EulaAccepted
                        $ErrorActionPreference = 'Stop'
                        If ($PropertyTest -eq $False) {
                            If ($isAutomated) {
                                Write-Output "$($i + 1) > skipping: '$($Description) because it has a license agreement that has not been accepted."
                            } Else {
                                Write-Output "$($i + 1) > note: '$($Description)' has a license agreement that must be accepted:"
                                Write-Output $Update.EulaText
                                $value = Read-Host -Prompt "Do you accept this license agreement? (Y/[N])"
                                If ($value.toLower -eq 'y') {
                                    $Update.AcceptEula()
                                    $AddThisUpdate = $true
                                } Else {
                                    Write-Output "$($i + 1) > skipping: '$($Description)' because the license agreement was not accepted."
                                }
                            }
                        }
                    }
                } Else {
                    $AddThisUpdate = $true
                }
            }
            If ($AddThisUpdate) {
                $PropertyTest = 0
                $ErrorActionPreference = 'SilentlyContinue'
                $PropertyTest = $Update.InstallationBehavior.Impact
                $ErrorActionPreference = 'Stop'
                If ($PropertyTest -eq 2) {
                    If ($AtLeastOneAdded) {
                        Write-Output "$($i + 1) > skipping: '$($Description)' because it is exclusive and other updates are being installed first."
                        $AddThisUpdate = $false
                    }
                }
            }
            If ($AddThisUpdate) {
                If (-not $isAutomated) {
                    $Value = Read-Host -Prompt "$($i + 1) > : '$($Description)' is applicable; do you want to install it? ([Y]/N)"
                    If ($Value.ToLower() -eq 'n') {
                        Write-Output "Skipping update"
                        $AddThisUpdate = $False
                    }
                }
            }
            If ($AddThisUpdate) {
                Write-Output "$($i + 1) > : adding '$($Description)'"
                $UpdatesToDownload.Add($Update)
                $AtLeastOneAdded = $true
                $ErrorActionPreference = 'SilentlyContinue'
                $PropertyTest = $Update.InstallationBehavior.Impact
                $ErrorActionPreference = 'Stop'
                If ($PropertyTest -eq 2) {
                    Write-Output "This update is exclusive; skipping remaining updates"
                    $ExclusiveAdded = $true
                }
            }
        }
    }

    $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
    $RebootMayBeRequired = $false

    If (-not $NoDownload) {
        Write-Output "Downloading updates..."
        $Downloader = $UpdateSession.CreateUpdateDownloader()
        $Downloader.Updates = $UpdatesToDownload
        $Downloader.Download()
        Write-Output "Succesfully downloaded updates:"

        For ($i = 0; $i -lt $UpdatesToDownload.Count; $i++) {
            $Update = $UpdatesToDownload.Item[$i]
            If ($Update.IsDownloaded -eq $true) {
                Write-Output "$($i + 1) > $(Get-UpdateDescription -Update $Update)"
                $UpdatesToInstall.Add($Update)
                $PropertyTest = 0
                $ErrorActionPreference = 'SilentlyContinue'
                $PropertyTest = $Update.InstallationBehavior.RebootBehavior
                $ErrorActionPreference = 'Stop'
                If ($PropertyTest -gt 0) {
                    $RebootMayBeRequired = $true
                }
            }
        }
    }

    If ($NoInstall) {
        Write-Output "Skipping install as requested."
    } Else {
        If ($UpdatesToInstall.Count -gt 0) {
            If ($RebootMayBeRequired = $true) {
                Write-Output "These updates may require a reboot."
            }
            $Install = $false
            If (-not $isAutomated) {
                $StringInput = Read-Host -Prompt "Would you like to install updates now? (Y/[N])"
                If ($StringInput.ToLower() -eq 'y') {
                    $Install = $true
                    Write-Output "Installing updates..."                    
                }
            } Else {
                $Install = $True
            }
            If ($Install) {
                $Installer = $UpdateSession.CreateUpdateInstaller()
                $Installer.Updates = $UpdatesToInstall
                $InstallationResult = $Installer.Install()

                $ReturnValue = 1
                Write-Output "Installation Result: $(Get-InstallationResultText -Result $($InstallationResult.ResultCode)) HRESULT: $($InstallationResult.GetUpdateResult[$i].HResult)"
                If ($InstallationResult.GetUpdateResult[$i].HResult -eq -2145116147) {
                    Write-Output "An updated needed additional downloaded content. Please rerun the script."
                }

                If ($InstallationResult.RebootRequired -and $RebootToComplete) {
                    If (-not $isAutomated) {
                        $Reboot = $false
                        $Reboot = Read-Host -Prompt "Would you like to reboot now to complete the installation? (Y/[N])"
                        If ($Reboot.ToLower -eq 'y') {
                            $Reboot = $true
                        }
                    } Else {
                        $Reboot = $true
                    }
                    If ($Reboot -eq $true) {
                        Write-Output "Triggering restart in 30 seconds..."
                        Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r /t 30'
                    }
                }
            }
        }
    }  
} 