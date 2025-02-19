Param(    
    [string]$ResourceManagerUri,
    [string]$SubscriptionId,
    [string]$UserAssignedIdentityClientId,
    [string]$VirtualMachineNames,
    [string]$VirtualMachinesResourceGroup
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

[array]$VirtualMachineNames = $VirtualMachineNames.replace('\"', '"') | ConvertFrom-Json

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

$ResourceGroupId = '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $VirtualMachinesResourceGroup

ForEach ($VMName in $VirtualMachineNames) {
    $null = $CustomScriptExtension
    $Extensions = Invoke-RestMethod `
                        -Headers $AzureManagementHeader `
                        -Method 'GET' `
                        -Uri $($ResourceManagerUriFixed + $ResourceGroupId + '/providers/Microsoft.Compute/virtualMachines/' + $VMName + '/extensions?api-version=2024-03-01')
    $CustomScriptExtension = ($Extensions.value | Where-Object {$_.properties.type -eq 'CustomScriptExtension'}).value.name  
    If($CustomScriptExtension) {
        Invoke-RestMethod `
            -Headers $AzureManagementHeader `
            -Method 'DELETE' `
            -Uri $($ResourceManagerUriFixed + $ResourceGroupId + '/providers/Microsoft.Compute/virtualMachines/' + $VmName + '/extensions/' + $CustomScriptExtension + '?api-version=2024-03-01') | Out-Null
    }
}