Param(
    [string]$ResourceGroupId,
    [string]$ResourceManagerUri,
    [string]$SessionHostCount,
    [string]$SessionHostIndex,
    [string]$UserAssignedIdentityClientId,
    [string]$VirtualMachineNamePrefix
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

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
[int]$SHCount = $SessionHostCount
[int]$SHIndex = $SessionHostIndex
for ($i = $SHIndex; $i -lt $($SHIndex + $SHCount); $i++) {
    $VmName = $VirtualMachineNamePrefix + $i.ToString().PadLeft(3,'0')
    $RunCommands = (Invoke-RestMethod `
        -Headers $AzureManagementHeader `
        -Method 'GET' `
        -Uri $($ResourceManagerUriFixed + $ResourceGroupId + '/providers/Microsoft.Compute/virtualMachines/' + $VmName + '/runCommands?api-version=2022-03-09')).value.name
    foreach ($RunCommand in $RunCommands) {
        Invoke-RestMethod `
            -Headers $AzureManagementHeader `
            -Method 'DELETE' `
            -Uri $($ResourceManagerUriFixed + $ResourceGroupId + '/providers/Microsoft.Compute/virtualMachines/' + $VmName + '/runCommands/' + $RunCommand + '?api-version=2022-03-09') | Out-Null
    }    
}