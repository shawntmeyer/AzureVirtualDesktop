param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceManagerUri,

    [Parameter(Mandatory=$true)]
    [string]$UserAssignedIdentityClientId,

    [Parameter(Mandatory=$true)]
    [string]$ImageVmResourceId,

    [Parameter(Mandatory=$true)]
    [string]$ManagementVmResourceId,

    [Parameter(Mandatory=$false)]
    [string]$ImageResourceId
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

Try {
    # Fix the resource manager URI since only AzureCloud contains a trailing slash
    $ResourceManagerUriFixed = if($ResourceManagerUri[-1] -eq '/'){$ResourceManagerUri.Substring(0,$ResourceManagerUri.Length - 1)} else {$ResourceManagerUri}

    # Get an access token for Azure resources
    $AzureManagementAccessToken = (Invoke-RestMethod -Headers @{Metadata="true"} -Uri $('http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + $ResourceManagerUriFixed + '&client_id=' + $UserAssignedIdentityClientId)).access_token

    # Set header for Azure Management API
    $AzureManagementHeader = @{
        'Content-Type'='application/json'
        'Authorization'='Bearer ' + $AzureManagementAccessToken
    }

    # Delete Image VM 
    Invoke-RestMethod -Headers $AzureManagementHeader -Method 'DELETE' -Uri $($ResourceManagerUriFixed + $ImageVmResourceId + '?api-version=2024-03-01')

    # Delete the Image (If it exists)
    If ($ImageResourceId -ne '') {
        Invoke-RestMethod -Headers $AzureManagementHeader -Method 'DELETE' -Uri $($ResourceManagerUriFixed + $ImageResourceId + '?api-version=2024-03-01')
    }
    # Wait for at least 20 seconds to allow the Run Command to complete. Run Commands have a minimum 20 secs execution time.
    Start-Sleep -seconds 20

    # Delete the Management VM
    Invoke-RestMethod -Headers $AzureManagementHeader -Method 'DELETE' -Uri $($ResourceManagerUriFixed + $ManagementVmResourceId + '?forceDeletion=true&api-version=2024-03-01')
}
catch {
    throw
}