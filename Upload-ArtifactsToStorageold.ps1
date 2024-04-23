param(
    # The Azure Environment containing the storage account.
    [Parameter(ParameterSetName='Deploy')]
    [Parameter(ParameterSetName='UpdateOnly')]
    [ValidateSet("AzureCloud","AzureUSGovernment")]
    [string]$AzureEnvironment = 'AzureCloud',
    # the folder containing the artifact sources
    [Parameter(ParameterSetName='Deploy', Mandatory=$false)]
    [Parameter(ParameterSetName='UpdateOnly', Mandatory=$false)]
    [string] $ArtifactsDir = "$PSScriptRoot\artifacts",
    # the temp folder to where the artifact sources are prepared to be uploaded to the storage account.
    [Parameter(ParameterSetName='Deploy', Mandatory=$false)]
    [Parameter(ParameterSetName='UpdateOnly')]
    [string] $TempDir = "$PSScriptRoot\temp",
    # Determines if this script will reach out to the Internet and download new source Files for the installers.
    [Parameter(ParameterSetName='Deploy', Mandatory=$false)]
    [Parameter(ParameterSetName='UpdateOnly', Mandatory=$false)]
    [bool] $DownloadNewSources = $true,
    # Teams Tenant Type to determine download Url
    [Parameter(ParameterSetName='Deploy', Mandatory=$false)]
    [Parameter(ParameterSetName='UpdateOnly', Mandatory=$false)]
    [ValidateSet("Commercial","GovernmentCommunityCloud","GovernmentCommunityCloudHigh","DepartmentOfDefense")]
    [string] $TeamsTenantType = "Commercial",
    #SubscriptionId. If not provided then the default context is used for deployment.
    [Parameter(ParameterSetName='Deploy')]
    [string]$SubscriptionId,
    # Determines whether or not to deploy/redeploy the storage account using BICEP and the parameter file contained in the storageAccount folder
    [Parameter(ParameterSetName='Deploy')]
    [switch]$DeployPrerequisites,
    # The Location where the AVD Management Resources are being deployed.
    [Parameter(Mandatory=$true, ParameterSetName='Deploy')]
    [string]$Location,
    # Whether or not to update the parameters file with the Artifacts Location and Storage Account Resource ID.
    [Parameter(ParameterSetName='Deploy')]
    [switch]$UpdateParameters,
    # The full resource ID of the existing storage account to update.
    [Parameter(ParameterSetName='UpdateOnly', Mandatory=$true)]
    [string]$StorageAccountResourceId,
    [Parameter(ParameterSetName='UpdateOnly', Mandatory=$true)]
    [string]$ManagedIdentityResourceID,
    # The container where the artifacts will be stored.
    [Parameter(ParameterSetName='UpdateOnly', Mandatory=$false)]
    [string]$ArtifactsContainerName = 'artifacts'
)

#region Variables

$Time = Get-Date -Format 'yyyyMMddhhmmss'
$FunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'sharedPowerShellFunctions'
$BicepPath = Join-Path -Path $PSScriptRoot -ChildPath 'imageManagementResources'
$Template = Join-Path -Path $BicepPath -ChildPath 'imageManagement.bicep'
$TemplateParameters = Join-Path -Path $BicepPath -ChildPath 'imageManagement.parameters.json'

#endregion Variables

Write-Verbose ("[{0} entered]" -f $MyInvocation.MyCommand)

. "$FunctionsPath\GeneralDeployment\Get-MSIInfo.ps1"
. "$FunctionsPath\Storage\Compress-SubFolderContents.ps1"
. "$FunctionsPath\Storage\Get-InternetFile.ps1"
. "$FunctionsPath\Storage\Get-InternetUrl.ps1"
. "$FunctionsPath\Storage\Add-ContentToBlobContainer.ps1"

#region Storage Account Deployment/update

Write-Verbose "###########################################################################"
Write-Verbose "## 1 - Deploy/Update Storage Account and gather variables                ##"
Write-Verbose "###########################################################################"

If ($DeployPrerequisites) {   
    Write-Output "Deploying/Updating prerequisite resources using BICEP template and parameter file." 
    New-AzDeployment -Name "ImageManagement-Prereqs-$Time" -Location $Location -TemplateFile $Template -TemplateParameterFile $TemplateParameters -verbose

    $DeploymentOutputs = (Get-AzSubscriptionDeployment -Name "ImageManagement-Prereqs-$Time").Outputs
    $ComputeGalleryResourceId = $DeploymentOutputs.computeGalleryResourceId.value
    $StorageAccountResourceId = $DeploymentOutputs.storageAccountResourceId.value
    $ManagedIdentityResourceId = $DeploymentOutputs.managedIdentityResourceId.value
    $ArtifactsContainerName = $DeploymentOutputs.blobContainerName.value
    Write-Output "Setting variables based on Deployment Outputs:`n"
    Write-Output "`t`$StorageAccountResourceID  = $StorageAccountResourceId"
    Write-Output "`t`$ManagedIdentityResourceID = $ManagedIdentityResourceId"
    Write-Output "`t`$ArtifactsContainerName    = $ArtifactsContainerName"
} Else {
    Write-Output "Gathering variables from provided Parameters:`n"
    Write-Output "`t`$StorageAccountResourceId = '$StorageAccountResourceId'"
    Write-Output "`t`$ArtifactsContainerName = '$ArtifactsContainerName'"
    $SubscriptionId = ($StorageAccountResourceId -Split('/'))[2]
    Write-Output "`t`$SubscriptionId = '$SubscriptionId'"
    If ((Get-AzContext).Subscription -ne $SubscriptionId) { Set-AzContext -Subscription $SubscriptionId }
}
$StorageAccountResourceGroup = ($StorageAccountResourceId -split('/'))[4]
Write-Output "`t`$StorageAccountResourceGroup = $StorageAccountResourceGroup"
$StorageAccountName = ($StorageAccountResourceId -split('/'))[-1]
Write-Output "`t`$StorageAccountName = $StorageAccountName"
$BlobEndpoint = (Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroup -StorageAccountName $StorageAccountName).PrimaryEndpoints.Blob
$ArtifactsContainerUrl = $BlobEndpoint + $ArtifactsContainerName.toLower() + '/'
Write-Output "`t`$ArtifactsContainerUrl = $ArtifactsContainerUrl"

#endregion

#region Download New Sources

$downloadFilePath = (Join-Path -Path $ArtifactsDir -ChildPath "downloads.parameters.json")
if ($DownloadNewSources -and (Test-Path -Path $downloadFilePath)) {
    Write-Verbose "###########################################################################"
    Write-Verbose "## 2 - Download New Source Files into the artifacts Directory            ##"
    Write-Verbose "###########################################################################"
    $downloadJson = Get-Content -Path $downloadFilePath -Raw -ErrorAction 'Stop'
    try {
        $Downloads = $downloadJson | ConvertFrom-Json -ErrorAction 'Stop'
    }
    catch {
        Write-Error "Configuration JSON content could not be converted to a PowerShell object" -ErrorAction 'Stop'
    }
    foreach ($Download in $Downloads.Artifacts) {
        $SoftwareName = $Download.Name
        Write-Output "--------------------------------------------------"
        Write-Output "## Start - $SoftwareName ##"        
        $OutputFile = Join-Path -Path $ArtifactsDir -ChildPath $Download.DestinationFilePath
        If ($Download.DownloadUrl -ne '') {
            Write-Output "Download Url directly available."
            $DownloadUrl = $Download.DownloadUrl
        }
        Elseif ($Download.WebSiteUrl -ne '' -and $Download.SearchString -ne '') {
            $WebSiteUrl = $Download.WebSiteUrl
            $SearchString = $Download.SearchString
            Write-Output "Determining download Url for latest version of '$SoftwareName' from '$WebsiteUrl'."
            $DownloadUrl = Get-InternetUrl -WebSiteUrl $WebSiteUrl -searchstring $SearchString -ErrorAction SilentlyContinue
        }
        Elseif ($Download.APIUrl -ne '') {
            $APIUrl = $Download.APIUrl
            $EdgeUpdatesJSON = Invoke-WebRequest -Uri $APIUrl -UseBasicParsing
            $content = $EdgeUpdatesJSON.content | ConvertFrom-Json      
            $Edgereleases = ($content | Where-Object {$_.Product -eq 'Stable'}).releases
            $latestrelease = $Edgereleases | Where-Object {$_.Platform -eq 'Windows' -and $_.Architecture -eq 'x64'} | Sort-Object ProductVersion | Select-Object -last 1
            $EdgeUrl = $latestrelease.artifacts.location
            $EdgeLatestStableVersion = $latestrelease.ProductVersion
            $policyfiles = ($content | Where-Object {$_.Product -eq 'Policy'}).releases
            $latestPolicyFile = $policyfiles | Where-Object {$_.ProductVersion -eq $EdgeLatestStableVersion}
            If (-not($latestPolicyFile)) {   
                $latestpolicyfile = $policyfiles | Sort-Object ProductVersion | Select-Object -last 1
            }  
            $EdgeTemplatesUrl = $latestpolicyfile.artifacts.Location   
            Write-Output "Getting download Urls for latest Edge browser and policy templates from '$APIUrl'."
            If ($SoftwareName -eq 'Edge Enterprise') {
                $DownloadUrl = $EdgeUrl
            }
            Elseif ($SoftwareName -eq 'Edge Enterprise Administrative Templates') {
                $DownloadUrl = $EdgeTemplatesUrl
            }
        }
        Elseif ($Download.GitHubRepo -ne '') {
            $Repo = $Download.GitHubRepo
            $FileNamePattern = $Download.GitHubFileNamePattern
            $ReleasesUri = "https://api.github.com/repos/$Repo/releases/latest"
            Write-Output "Retrieving the url of the latest version from '$Repo' Github repo."
            $DownloadUrl = ((Invoke-RestMethod -Method GET -Uri $ReleasesUri).assets | Where-Object name -like $FileNamePattern).browser_download_url
        }
        ElseIf ($Download.Name -like 'Teams*') {
            If($TeamsTenantType-eq "Commercial") {
                $DownloadUrl = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
            }
            If($TeamsTenantType-eq "DepartmentOfDefense") {
                $DownloadUrl = "https://dod.teams.microsoft.us/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
            }
            If($TeamsTenantType-eq "GovernmentCommunityCloud") {
                $DownloadUrl = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&ring=general_gcc&download=true"
            }
            If($TeamsTenantType-eq "GovernmentCommunityCloudHigh") {
                $DownloadUrl = "https://gov.teams.microsoft.us/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
            }            
        }

        If (($DownloadUrl -ne '') -and ($null -ne $DownloadUrl)) {
            Write-Output "Downloading '$SoftwareName'."
            Try {
                If (Test-Path -Path $OutputFile) {
                    Remove-Item -Path $OutputFile -Force
                }
                $DestDir = split-path $outputFile -parent
                $DestFile = split-path $outputFile -leaf
                # Build Version File for Artifacts Directory
                $versionFileName = [System.IO.Path]::GetFileNameWithoutExtension($OutputFile) + "-fileinfo.txt"
                $VersionFilePath = Join-Path $DestDir -ChildPath $versionFileName
                $VersionText = @()
                $VersionText += "DownloadUrl = $DownloadUrl"
                If (!(Test-Path -Path $DestDir)) {
                    New-Item -Path $DestDir -ItemType Directory -Force
                }
                Try {
                    # Not supplying the destination file name first so we can try to get the original file name that was downloaded for version information.
                    $DownloadedFile = Get-InternetFile -Url $DownloadUrl -OutputDirectory $DestDir -Verbose
                    If ($DownloadedFile -ne $OutputFile) {
                        $VersionText += "Download File = $(split-path $DownloadedFile -leaf)"
                        Rename-Item -Path $DownloadedFile -NewName $DestFile -Force
                    }
                } Catch {
                    $DownloadedFile = Get-InternetFile -Url $DownloadUrl -OutputDirectory $DestDir -OutputFileName $DestFile
                    $VersionText += "Download File = $(split-path $DownloadedFile -leaf)"
                }
                Write-Output "Finished downloading '$SoftwareName' from Internet."

                Write-Output "Saving File Information to '$VersionFilePath'"

                If ([System.IO.Path]::GetExtension($OutputFile) -eq '.msi') {
                    $VersionText += Get-MSIInfo -Path $OutputFile
                } Elseif ([System.IO.Path]::GetExtension($OutputFile) -eq '.exe') {
                    $Version = (Get-ItemProperty -Path $OutputFile).VersionInfo | Select-Object ProductVersion, FileVersion
                    $VersionText += "$Version"
                }
                $VersionText | Out-File $VersionFilePath -Force
            }
            Catch {
                Write-Warning "Error downloading software from '$DownloadUrl'."
            }
        }
        Else {
            Write-Warning "No Internet URL found for '$SoftwareName'."
        }
        Write-Output "## End - $SoftwareName ##"
        Write-Output "--------------------------------------------------"             
    }
}
else {
    Write-Verbose "No software configured to be downloaded"
}
#endregion Download New Sources

#region Compress contents of Artifacts Subdirectories

Write-Verbose "###########################################################################"
Write-Verbose "## 3 - Create Zip files for all subfolders inside `$ArtifactsDir.        ##"
Write-Verbose "###########################################################################"

If (Test-Path -Path $TempDir) {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path $TempDir -ItemType Directory -Force

if ($PSCmdlet.ShouldProcess("[$ArtifactsDir] subfolders as .zip and store them into [$TempDir]", "Compress")) {
    Compress-SubFolderContents -SourceFolderPath $ArtifactsDir -DestinationFolderPath $TempDir -Verbose
    Write-Verbose "Artifact Source Files compression finished"
}
Write-Verbose "Copying files in root of '$ArtifactsDir' to '$TempDir'."
Get-ChildItem -Path $ArtifactsDir -file | Where-Object {$_.FullName -ne "$downloadFilePath"} | Copy-Item -Destination $TempDir -Force

#endregion Compress Artifacts

#region Upload Blobs to Storage Account

Write-Verbose "###########################################################################"
Write-Verbose "## 4 - Upload all files in `$TempDir to Storage Account.                 ##"
Write-Verbose "###########################################################################"
if ($DeleteExistingBlobs) {
    Write-Output "Existing Blobs in Storage Account '$StorageAccountName' are now being deleted."
    $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
    Get-AzStorageBlob -Container $AssetsContainerName -Context $ctx | Remove-AzStorageBlob -Force
}

if ($PSCmdlet.ShouldProcess("storage account '$storageAccountName'", "Uploading Blobs to")) {
    Add-ContentToBlobContainer -ResourceGroupName $StorageAccountResourceGroup -StorageAccountName $StorageAccountName -contentDirectories $TempDir -TargetContainer $ArtifactsContainerName -Verbose
    Write-Verbose "Storage account content upload invocation finished"
}

Get-ChildItem -Path $TempDir -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

#endregion

#region Dynamically Update Parameters file
If ($UpdateParameters) {
    $ParametersFile = (Get-Item -Path "$PSScriptRoot\imageBuild.parameters.json").FullName
    $JSON = Get-Content -Path $ParametersFile | ConvertFrom-Json
    $JSON.parameters.computeGalleryResourceId.value = $ComputeGalleryResourceId
    $JSON.parameters.storageAccountResourceId.value = $StorageAccountResourceId
    $JSON.parameters.userAssignedIdentityResourceId.value = $ManagedIdentityResourceId
    $JSON | ConvertTo-Json -Depth 32 | Out-File $ParametersFile
}
#endregion

#region Output Storage Account Information
Write-Output "The 'ArtifactsLocation'                       = '$ArtifactsContainerUrl'."
Write-Output "The 'ArtifactsUserAssignedIdentityResourceId' = '$ManagedIdentityResourceId'."
#endregion
Write-Verbose ("[{0} exited]" -f $MyInvocation.MyCommand)