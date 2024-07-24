param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceManagerUri = 'https://management.azure.com',

    [Parameter(Mandatory=$true)]
    [string]$UserAssignedIdentityClientId = '2821a55d-6777-4069-8096-66993e9b1d26',

    [Parameter(Mandatory=$true)]
    [string]$ManagementVmResourceId = '/subscriptions/6638b757-bc2e-43a8-9274-1d7e2961563d/resourceGroups/rg-image-builder-usw2/providers/Microsoft.Compute/virtualMachines/avd-vmmgt-dnvsb'

)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

Try {
    # Fix the resource manager URI since only AzureCloud contains a trailing slash
    $ResourceManagerUriFixed = if($ResourceManagerUri[-1] -eq '/'){$ResourceManagerUri.Substring(0,$ResourceManagerUri.Length - 1)} else {$ResourceManagerUri}

    # Get an access token for Azure resources
    $AzureManagementAccessToken = (Invoke-RestMethod `
        -Headers @{Metadata="true"} `
        -Uri $('http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + $ResourceManagerUriFixed + '&client_id=' + $UserAssignedIdentityClientId)).access_token

    # Set header for Azure Management API
    $AzureManagementHeader = @{
        'Content-Type'='application/json'
        'Authorization'='Bearer ' + $AzureManagementAccessToken
    }

    $ScriptBlock = { param ($AzureManagementHeader, $ResourceManagerUriFixed, $ManagementVmResourceId) Invoke-RestMethod -Headers $AzureManagementHeader -Method 'DELETE' -Uri $($ResourceManagerUriFixed + $ManagementVmResourceId + '?api-version=2024-03-01')}
    # Delete the Management VM (Don't wait to prevent deployment failure.)
    Start-Job -ScriptBlock $ScriptBlock -ArgumentList $AzureManagementHeader, $ResourceManagerUri, $ManagementVmResourceId -Name 'DeleteManagementVm'
    Get-Job -Name 'DeleteManagementVm'
}
catch {
    throw
}