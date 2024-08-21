Param(
    [string]$HostPoolResourceId,
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

# Get the AVD session hosts
$SessionHosts = (Invoke-RestMethod `
    -Headers $AzureManagementHeader `
    -Method 'GET' `
    -Uri $($ResourceManagerUriFixed + $HostPoolResourceId + '/sessionHosts?api-version=2023-09-05')).value.name

$HostPoolName = $HostPoolResourceId.Split('/')[8]    
# Enable drain mode for the AVD session hosts
[int]$SHCount = $SessionHostCount
[int]$SHIndex = $SessionHostIndex
for($i = $SHIndex; $i -lt $($SHIndex + $SHCount); $i++)
{
    $VmNameFull = $VirtualMachineNamePrefix + $i.ToString().PadLeft(3,'0')
    $SessionHostName = ($SessionHosts | Where-Object {$_ -like "*$VmNameFull*"}).Replace("$HostPoolName/", '')
    Invoke-RestMethod `
        -Body (@{properties = @{allowNewSession = $false}} | ConvertTo-Json) `
        -Headers $AzureManagementHeader `
        -Method 'PATCH' `
        -Uri $($ResourceManagerUriFixed + $HostPoolResourceId + '/sessionHosts/' + $SessionHostName + '?api-version=2023-09-05') | Out-Null
}