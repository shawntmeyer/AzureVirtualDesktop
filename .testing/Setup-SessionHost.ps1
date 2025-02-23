<#

.SYNOPSIS
Set up a VM as session host to existing/new host pool.

.DESCRIPTION
This script installs RD agent and verify that it is successfully registered as session host to existing/new host pool.

#>
param(
    [Parameter(mandatory = $true)]
    [string]$HostPoolName,

    [Parameter(Mandatory = $false)]
    [string]$RegistrationInfoToken="",

    [Parameter(mandatory = $false)] 
    [pscredential]$RegistrationInfoTokenCredential = $null,

    [Parameter(Mandatory = $false)]
    [bool]$AadJoin = $false,

    [Parameter(Mandatory = $false)]
    [bool]$AadJoinPreview = $false,

    [Parameter(Mandatory = $false)]
    [string]$MdmId = "",

    [Parameter(Mandatory = $false)]
    [string]$SessionHostConfigurationLastUpdateTime = "",

    [Parameter(mandatory = $false)] 
    [switch]$EnableVerboseMsiLogging,
    
    [Parameter(Mandatory = $false)]
    [bool]$UseAgentDownloadEndpoint = $false
)
$ScriptPath = [system.io.path]::GetDirectoryName($PSCommandPath)

function Write-Log {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$Err
    )
     
    try {
        $DateTime = Get-Date -Format "MM-dd-yy HH:mm:ss"
        $Invocation = "$($MyInvocation.MyCommand.Source):$($MyInvocation.ScriptLineNumber)"

        if ($Err) {
            $Message = "[ERROR] $Message"
        }
        
        Add-Content -Value "$DateTime - $Invocation - $Message" -Path "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\ScriptLog.log"
    }
    catch {
        throw [System.Exception]::new("Some error occurred while writing to log file with message: $Message", $PSItem.Exception)
    }
}

function IsRDAgentRegistryValidForRegistration {
    $ErrorActionPreference = "Stop"

    $RDInfraReg = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent' -ErrorAction SilentlyContinue
    if (!$RDInfraReg) {
        return @{
            result = $false;
            msg    = 'RD Infra registry missing';
        }
    }
    Write-Log -Message 'RD Infra registry exists'
    Write-Log -Message 'Check RD Infra registry values to see if RD Agent is registered'
    if ($RDInfraReg.RegistrationToken -ne '') {
        return @{
            result = $false;
            msg    = 'RegistrationToken in RD Infra registry is not empty'
        }
    }
    if ($RDInfraReg.IsRegistered -ne 1) {
        return @{
            result = $false;
            msg    = "Value of 'IsRegistered' in RD Infra registry is $($RDInfraReg.IsRegistered), but should be 1"
        }
    }    
    return @{
        result = $true
    }
}

function GetAgentInstaller {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RegistrationToken,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentInstallerFolder
    )

    Try {
        $ParsedToken = ParseRegistrationToken $RegistrationToken
        if (-not $ParsedToken.GlobalBrokerResourceIdUri) {
            Write-Log -Message "Unable to obtain broker agent check endpoint"
            return
        }

        $BrokerAgentUri = [System.UriBuilder] $ParsedToken.GlobalBrokerResourceIdUri
        $BrokerAgentUri.Path = "api/agentMsi/v1/agentVersion"
        $BrokerAgentUri = $BrokerAgentUri.Uri.AbsoluteUri
        Write-Log -Message "Obtained broker agent api $BrokerAgentUri"

        $AgentMSIEndpointUri = [System.UriBuilder] (GetAgentMSIEndpoint $BrokerAgentUri)
        if (-not $AgentMSIEndpointUri) {
            Write-Log -Message "Unable to get Agent MSI endpoints from storage blob"
            return
        }

        $AgentDownloadFolder = New-Item -Path $AgentInstallerFolder -Name "RDAgent" -ItemType "directory" -Force
        $PrivateLinkAgentMSIEndpointUri = [System.UriBuilder] $AgentMSIEndpointUri.Uri.AbsoluteUri
        $PrivateLinkAgentMSIEndpointUri.Host = "$($ParsedToken.EndpointPoolId).$($AgentMSIEndpointUri.Host)"
        Write-Log -Message "Attempting to download agent msi from $($AgentMSIEndpointUri.Uri.AbsoluteUri), or $($AgentMSIEndpointUri.Uri.AbsoluteUri)"

        $AgentInstaller = DownloadAgentMSI $AgentMSIEndpointUri $PrivateLinkAgentMSIEndpointUri $AgentDownloadFolder
        if (-not $AgentInstaller) {
            Write-Log -Message "Failed to download agent msi from $AgentMSIEndpointUri"
        } else {
            Write-Log "Successfully downloaded the agent from $AgentMSIEndpointUri"
        }

        return $AgentInstaller
    } 
    Catch {
        Write-Log -Err "There was an error while downloading agent msi"
        Write-Log -Err $_.Exception.Message
    }
}

function GetAgentMSIEndpoint {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $BrokerAgentApi
    )

    Set-StrictMode -Version 1.0
    $ErrorActionPreference = "Stop"

    try {
        Write-Log -Message "Invoking broker agent api $BrokerAgentApi to get msi endpoint"
        $result = Invoke-WebRequest -Uri $BrokerAgentApi -UseBasicParsing
        $responseJson = $result.Content | ConvertFrom-Json
    }
    catch {
        $responseBody = $_.ErrorDetails.Message
        Write-Log -Err $responseBody
        return $null
    }

    Write-Log -Message "Obtained agent msi endpoint $($responseJson.agentEndpoint)"
    return $responseJson.agentEndpoint
}

function DownloadAgentMSI {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PrivateLinkAgentEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentDownloadFolder
    )
    
    Set-StrictMode -Version 1.0

    $AgentInstaller = $null

    try {
        Write-Log -Message "Trying to download agent msi from $AgentEndpoint"
        Invoke-WebRequest -Uri $AgentEndpoint -OutFile "$AgentDownloadFolder\RDAgent.msi"
        $AgentInstaller = Join-Path $AgentDownloadFolder "RDAgent.msi"
    } 
    catch {
        Write-Log -Err "Error while downloading agent msi from $AgentEndpoint"
        Write-Log -Err $_.Exception.Message
    }

    if (-not $AgentInstaller) {
        try {
            Write-Log -Message "Trying to download agent msi from $PrivateLinkAgentEndpoint"
            Invoke-WebRequest -Uri $AgentEndpoint -OutFile "$AgentDownloadFolder\RDAgent.msi"
            $AgentInstaller = Join-Path $AgentDownloadFolder "RDAgent.msi"
        } 
        catch {
            Write-Log -Err "Error while downloading agent msi from $PrivateLinkAgentEndpoint"
            Write-Log -Err $_.Exception.Message
        }
    }

    return $AgentInstaller
}

function ParseRegistrationToken {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$RegistrationToken
    )
 
    Set-StrictMode -Version 1.0
    $ClaimsSection = $RegistrationToken.Split(".")[1].Replace('-', '+').Replace('_', '/')
    while ($ClaimsSection.Length % 4) { 
        $ClaimsSection += "=" 
    }
    
    $ClaimsByteArray = [System.Convert]::FromBase64String($ClaimsSection)
    $ClaimsArray = [System.Text.Encoding]::ASCII.GetString($ClaimsByteArray)
    $Claims = $ClaimsArray | ConvertFrom-Json
    return $Claims
}

function InstallRDAgents {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentInstallerFolder,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentBootServiceInstallerFolder,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RegistrationToken
    )

    $ErrorActionPreference = "Stop"

    Write-Log -Message "Boot loader folder is $AgentBootServiceInstallerFolder"
    Write-Log -Message "Obtaining agent installer"
    $AgentInstaller = GetAgentInstaller $RegistrationToken $AgentInstallerFolder
    if (-not $AgentInstaller) {
        Write-Log -Err -Message "Unable to download latest agent msi from storage blob."
        Exit 1
    }
    <#
    $msiNamesToUninstall = @(
        @{ msiName = "Remote Desktop Services Infrastructure Agent"; displayName = "RD Infra Agent"; logPath = "C:\Users\AgentUninstall.txt"}, 
        @{ msiName = "Remote Desktop Agent Boot Loader"; displayName = "RDAgentBootLoader"; logPath = "C:\Users\AgentBootLoaderUnInstall.txt"}
    )

    foreach($u in $msiNamesToUninstall) {
        while ($true) {
            try {
                $installedMsi = Get-Package -ProviderName msi -Name $u.msiName
            }
            catch {
                #Ignore the error if it was due to no packages being found.
                if ($PSItem.FullyQualifiedErrorId -eq "NoMatchFound,Microsoft.PowerShell.PackageManagement.Cmdlets.GetPackage") {
                    break
                }
    
                throw;
            }
    
            $oldVersion = $installedMsi.Version
            $productCodeParameter = $installedMsi.FastPackageReference
    
            RunMsiWithRetry -programDisplayName "$($u.displayName) $oldVersion" -isUninstall -argumentList @("/x $productCodeParameter", "/quiet", "/qn", "/norestart", "/passive") -msiOutputLogPath $u.logPath -msiLogVerboseOutput:$EnableVerboseMsiLogging
        }
    }

    Write-Log -Message "Installing RD Infra Agent on VM $AgentInstaller"
    RunMsiWithRetry -programDisplayName "RD Infra Agent" -argumentList @("/i $AgentInstaller", "/quiet", "/qn", "/norestart", "/passive", "REGISTRATIONTOKEN=$RegistrationToken")

    Write-Log -Message "Installing RDAgent BootLoader on VM $AgentBootServiceInstaller"
    RunMsiWithRetry -programDisplayName "RDAgent BootLoader" -argumentList @("/i $AgentBootServiceInstaller", "/quiet", "/qn", "/norestart", "/passive")

    $bootloaderServiceName = "RDAgentBootLoader"
    $startBootloaderRetryCount = 0
    while ( -not (Get-Service $bootloaderServiceName -ErrorAction SilentlyContinue)) {
        $retry = ($startBootloaderRetryCount -lt 6)
        $msgToWrite = "Service $bootloaderServiceName was not found. "
        if ($retry) { 
            $msgToWrite += "Retrying again in 30 seconds, this will be retry $startBootloaderRetryCount" 
            Write-Log -Message $msgToWrite
        } 
        else {
            $msgToWrite += "Retry limit exceeded" 
            Write-Log -Err $msgToWrite
            throw $msgToWrite
        }
            
        $startBootloaderRetryCount++
        Start-Sleep -Seconds 30
    }

    Write-Log -Message "Starting service $bootloaderServiceName"
    Start-Service $bootloaderServiceName
#>
}

function RunMsiWithRetry {
    param(
        [Parameter(mandatory = $true)]
        [string]$programDisplayName,

        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$argumentList, #Must have at least 1 value

         [Parameter(mandatory = $false)]
        [switch]$isUninstall

    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    $retryTimeToSleepInSec = 30
    $retryCount = 0
    $sts = $null
    do {
        $modeAndDisplayName = ($(if ($isUninstall) { "Uninstalling" } else { "Installing" }) + " $programDisplayName")

        if ($retryCount -gt 0) {
            Write-Log -Message "Retrying $modeAndDisplayName in $retryTimeToSleepInSec seconds because it failed with Exit code=$sts This will be retry number $retryCount"
            Start-Sleep -Seconds $retryTimeToSleepInSec
        }

        Write-Log -Message ( "$modeAndDisplayName" + $(if ($msiLogVerboseOutput) { " with verbose msi logging" } else { "" }))

        $processResult = Start-Process -FilePath "msiexec.exe" -ArgumentList $argumentList -Wait -Passthru
        $sts = $processResult.ExitCode

        $retryCount++
    } 
    while ($sts -eq 1618 -and $retryCount -lt 20)
    if ($sts -eq 1618) {
        Write-Log -Err "Stopping retries for $modeAndDisplayName. The last attempt failed with Exit code=$sts which is ERROR_INSTALL_ALREADY_RUNNING"
        throw "Stopping because $modeAndDisplayName finished with Exit code=$sts"
    }
    else {
        Write-Log -Message "$modeAndDisplayName finished with Exit code=$sts"
    }
    return $sts
}

































# Setting ErrorActionPreference to stop script execution when error occurs
$ErrorActionPreference = "Stop"

# Checking if RDInfragent is registered or not in rdsh vm
Write-Log -Message "Checking whether VM was Registered with RDInfraAgent"
$RegistryCheckObj = IsRDAgentRegistryValidForRegistration

$RegistrationInfoTokenValue = ""
if ($null -eq $RegistrationInfoTokenCredential) {
    $RegistrationInfoTokenValue = $RegistrationInfoToken
} else {
    $RegistrationInfoTokenValue = $RegistrationInfoTokenCredential.GetNetworkCredential().Password
}

if ($RegistryCheckObj.result)
{
    Write-Log -Message "VM was already registered with RDInfraAgent, script execution was stopped"
}
else
{
    Write-Log -Message "Creating a folder inside rdsh vm for extracting deployagent zip file"
    $DeployAgentLocation = "C:\DeployAgent"
    $null = New-Item -ItemType Directory -Path $DeployAgentLocation -Force
    Write-Log -Message "Changing current folder to Deployagent folder: $DeployAgentLocation"
    Set-Location "$DeployAgentLocation"
    Write-Log -Message "VM not registered with RDInfraAgent, script execution will continue"
    Write-Log "AgentInstaller is $DeployAgentLocation\RDAgentBootLoaderInstall, InfraInstaller is $DeployAgentLocation\RDInfraAgentInstall"
    $null = New-Item -ItemType Directory -Path "$DeployAgentLocation\RDAgentBootLoaderInstall" -Force
    $null = New-Item -ItemType Directory -Path "$DeployAgentLocation\RDInfraAgentInstall" -Force

    if ($AadJoinPreview) {
        Write-Log "Azure ad join preview flag enabled"
        $registryPath = "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AzureADJoin"
        if (Test-Path -Path $registryPath) {
            Write-Log "Setting reg key JoinAzureAd"
            New-ItemProperty -Path $registryPath -Name JoinAzureAD -PropertyType DWord -Value 0x01
        } else {
            Write-Log "Creating path for azure ad join registry keys: $registryPath"
            New-item -Path $registryPath -Force | Out-Null
            Write-Log "Setting reg key JoinAzureAD"
            New-ItemProperty -Path $registryPath -Name JoinAzureAD -PropertyType DWord -Value 0x01
        }
        if ($MdmId) {
            Write-Log "Setting reg key MDMEnrollmentId"
            New-ItemProperty -Path $registryPath -Name MDMEnrollmentId -PropertyType String -Value $MdmId
        }
    }

    InstallRDAgents -AgentBootServiceInstallerFolder "$DeployAgentLocation\RDAgentBootLoaderInstall" -AgentInstallerFolder "$DeployAgentLocation\RDInfraAgentInstall" -RegistrationToken $RegistrationInfoTokenValue -EnableVerboseMsiLogging:$false -UseAgentDownloadEndpoint $UseAgentDownloadEndpoint

    Write-Log -Message "The agent installation code was successfully executed and RDAgentBootLoader, RDAgent installed inside VM for existing hostpool: $HostPoolName"
}



Write-Log -Message "Session Host Configuration Last Update Time: $SessionHostConfigurationLastUpdateTime"
$rdInfraAgentRegistryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent"
if (Test-path $rdInfraAgentRegistryPath) {
    Write-Log -Message ("Write SessionHostConfigurationLastUpdateTime '$SessionHostConfigurationLastUpdateTime' to $rdInfraAgentRegistryPath")
    Set-ItemProperty -Path $rdInfraAgentRegistryPath -Name "SessionHostConfigurationLastUpdateTime" -Value $SessionHostConfigurationLastUpdateTime
}

if ($AadJoin -and -not $AadJoinPreview) {
    # 6 Minute sleep to guarantee intune metadata logging
    Write-Log -Message ("Configuration.ps1 complete, sleeping for 6 minutes")
    Start-Sleep -Seconds 360
    Write-Log -Message ("Configuration.ps1 complete, waking up from 6 minute sleep")
}

$SessionHostName = GetAvdSessionHostName
Write-Log -Message "Successfully registered VM '$SessionHostName' to HostPool '$HostPoolName'"