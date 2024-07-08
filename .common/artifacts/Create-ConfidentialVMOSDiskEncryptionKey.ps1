[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Environment,

    [Parameter(Mandatory = $true)]
    [String]
    $KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]
    $KeyName,

    [Parameter(Mandatory = $true)]
    [string]
    $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]
    $TenantId,

    [Parameter(Mandatory = $true)]
    [string]
    $UserAssignedIdentityClientId,

    [Parameter(Mandatory = $false)]
    [hashtable]
    $Tags
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

$PolicyContentJson = @"
{"version":"1.0.0","anyOf":[{"authority":"https://sharedeus.eus.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedwus.wus.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedneu.neu.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedweu.weu.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedsasia.sasia.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedeasia.easia.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedjpe.jpe.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedswn.swn.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://shareditn.itn.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedeus2.eus2.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedeus2e.eus2e.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedscus.scus.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedcuse.cuse.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedcus.cus.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedeau.eau.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedsau.sau.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedcin.cin.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://shareduaen.uaen.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://shareddewc.dewc.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]},{"authority":"https://sharedwus3.wus3.attest.azure.net/","allOf":[{"claim":"x-ms-compliance-status","equals":"azure-compliant-cvm"},{"anyOf":[{"claim":"x-ms-attestation-type","equals":"tdxvm"},{"claim":"x-ms-attestation-type","equals":"sevsnpvm"}]}]}]}
"@


try 
{
    If ($Environment -eq 'USNat') {
        Add-AzEnvironment -AutoDiscover -Uri 'https://management.azure.eaglex.ic.gov/metadata/endpoints?api-version=2022-06' *> $null
    } ElseIf ($Environment -eq 'USSec') {
        Add-AzEnvironment -AutoDiscover -Uri 'https://management.azure.microsoft.scloud/metadata/endpoints?api-version=2022-06' *> $null
    }
    Connect-AzAccount -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId -Identity -AccountId $UserAssignedIdentityClientId *> $null
        
    $Key = Get-AzKeyVaultKey -VaultName $KeyVaultName | Where-Object { $_.Name -eq $KeyName }
    If ($Key) {
        $KeyUriWithVersion = ((Get-AzKeyVaultKey -VaultName $KeyVaultName -Name $KeyName -IncludeVersions).id).Replace(':443', '')
    } else {
        $ReleasePolicyPath = Join-Path -Path $env:TEMP -ChildPath 'confidentialVMReleasePolicy.json'
        $PolicyContentJson | ConvertFrom-Json | ConvertTo-Json -Depth 100 | Out-File -FilePath $ReleasePolicyPath -Force -Encoding utf8
        $Key = Add-AzKeyVaultKey -VaultName $KeyVaultName -Name $KeyName -KeyType 'RSA-HSM' -Size 4096 -Destination 'Software' -ReleasePolicyPath $ReleasePolicyPath -Exportable -Tag $Tags
        $KeyUriWithVersion = $($Key.Id).Replace(':443', '')
    }
    
    Disconnect-AzAccount | Out-Null

    $Output = [PSCustomObject][ordered]@{
        KeyUriWithVersion = $KeyUriWithVersion
    }
    $JsonOutput = $Output | ConvertTo-Json
    return $JsonOutput
}
catch 
{
    Write-Error -Message "Failed to create or retrieve the key from the Key Vault. $_"
    throw
}