[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $AutomationAccountName,
    [Parameter()]
    [string]
    $Environment,
    [Parameter()]
    [string]
    $ResourceGroupName,
    [Parameter()]
    [string]
    $RunbookName,
    [Parameter()]
    [string]
    $ScriptPath,
    [Parameter()]
    [string]
    $SubscriptionId,
    [Parameter()]
    [string]
    $TenantId,
    [Parameter()]
    [string]
    $UserAssignedIdentityClientId
)



function Write-Log
{
    param(
        [parameter(Mandatory)]
        [string]$Message,
        
        [parameter(Mandatory)]
        [string]$Type
    )
    $Path = 'C:\cse.txt'
    if(!(Test-Path -Path $Path))
    {
        New-Item -Path 'C:\' -Name 'cse.txt' | Out-Null
    }
    $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
    $Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
    $Entry | Out-File -FilePath $Path -Append
}

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

try 
{
    If ($Tags) {
        [hashtable]$HashTags = $Tags | ConvertFrom-Json
    } Else {
        [hashtable]$HashTags = @{}
    }
    If (-not (Test-Path $ScriptPath)) {
        $ScriptPath = Get-ChildItem -Path $PSScriptRoot -Filter "$(Split-Path -Path $ScriptPath -Leaf)" -Recurse
    }
    Connect-AzAccount -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId -Identity -AccountId $UserAssignedIdentityClientId | Out-Null
    Import-AzAutomationRunbook -Name $RunbookName -Path $ScriptPath -Type PowerShell -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Published -Description 'This script automates host pool scaling.' -Force | Out-Null
    Write-Log -Message "Published RunBook: [$RunBookName] to Automation Account: [$AutomationAccountName]" -Type 'INFO'
    $Output = [pscustomobject][ordered]@{
        RunbookName = $RunbookName
    }

    Disconnect-AzAccount | Out-Null

    $JsonOutput = $Output | ConvertTo-Json
    return $JsonOutput
}
catch 
{
    Write-Log -Message $_ -Type 'ERROR'
    throw
}