Param(
    [parameter(Mandatory)]
    [string]$ApplicationGroupName,

    [parameter(Mandatory)]
    [string]$Environment,

    [parameter(Mandatory)]
    [string]$FriendlyName,

    [parameter(Mandatory)]
    [string]$ResourceGroupName,

    [parameter(Mandatory)]
    [string]$SubscriptionId,

    [parameter(Mandatory)]
    [string]$TenantId,

    [parameter(Mandatory)]
    [string]$UserAssignedIdentityClientId
)

$ErrorActionPreference = 'Stop'

try
{
    If ($Environment -eq 'USNat') {
        Add-AzEnvironment -AutoDiscover -Uri 'https://management.azure.eaglex.ic.gov/metadata/endpoints?api-version=2022-06' *> $null
    } ElseIf ($Environment -eq 'USSec') {
        Add-AzEnvironment -AutoDiscover -Uri 'https://management.azure.microsoft.scloud/metadata/endpoints?api-version=2022-06' *> $null
    }
    
    Connect-AzAccount `
        -Environment $Environment `
        -Tenant $TenantId `
        -Subscription $SubscriptionId `
        -Identity `
        -AccountId $UserAssignedIdentityClientId *> $null

    Update-AzWvdDesktop `
        -ApplicationGroupName $ApplicationGroupName `
        -Name 'SessionDesktop' `
        -ResourceGroupName $ResourceGroupName `
        -FriendlyName $FriendlyName.Replace('"', '') | Out-Null

    Disconnect-AzAccount | Out-Null

    $Output = [pscustomobject][ordered]@{
        applicationGroupName = $ApplicationGroupName
    }
    $JsonOutput = $Output | ConvertTo-Json
    return $JsonOutput
}
catch 
{
    Write-Host $_ | Select-Object *
    throw
}