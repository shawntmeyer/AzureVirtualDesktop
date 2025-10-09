param(
    [string]$FileShareName,
    [string]$StorageAccountName,
    [string]$StorageSuffix
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ResourceUrl = 'https://' + $StorageAccountName + '.file.' + $StorageSuffix + '/'

$AccessToken = (Invoke-RestMethod `
        -Headers @{Metadata = "true" } `
        -Uri $('http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + $ResourceUrl + '&client_id=' + $UserAssignedIdentityClientId)).access_token

#$AccessToken = (Get-AzAccessToken -ResourceUrl $ResourceUrl).Token
$SDDL = 'O:BAG:SYD:PAI(A;OICIIO;0x1301bf;;;CO)(A;;0x1301bf;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)'

# example with SID O:BAG:SYD:PAI(A;OICIIO;0x1301bf;;;CO)(A;;0x1301bf;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;;0x1301bf;;;S-1-5-21-931057952-3365494314-315739458-1003)
$Headers = @{
    'x-ms-version'             = '2024-11-04'
    'x-ms-date'                = (Get-Date).ToUniversalTime().ToString('R')
    'x-ms-file-request-intent' = 'backup'
}
$Body = @{
    permission = 'O:SYG:SYD:PAI(A;OICIIO;0x1301bf;;;CO)(A;OICI;0x1301bf;;;AU)(A;OICI;FA;;;SY)'
    format     = 'sddl'
} | ConvertTo-Json
$Uri = $($ResourceUrl + $FileShareName + '?restype=share&comp=filepermission')

# Create Permission API call to create the permission key
$Response = Invoke-WebRequest -Authentication 'Bearer' -Body $Body -Headers $Headers -Method 'PUT' -Token $AccessToken -Uri $Uri -SslProtocol 'Tls12' -RetryIntervalSec 60 -MaximumRetryCount 5

# Get Directory Properties API call to force metadata creation
$Headers = @{
    'x-ms-version'             = '2024-11-04'
    'x-ms-date'                = (Get-Date).ToUniversalTime().ToString('R')
    'x-ms-file-request-intent' = 'backup'
}
Invoke-WebRequest -Authentication 'Bearer' -Headers $Headers -Method 'GET' -Token $AccessToken -Uri $($ResourceUrl + $FileShareName + '?restype=directory') | Out-Null

# Set Directory Properties API call to set the NTFS permissions on the root of the file share
$Headers = @{
    'Content-Type'              = 'application/json'
    'x-ms-date'                 = (Get-Date).ToUniversalTime().ToString('R')
    'x-ms-version'              = '2024-11-04'
    'x-ms-file-creation-time'   = 'preserve'
    'x-ms-file-last-write-time' = 'preserve'
    'x-ms-file-request-intent'  = 'backup'
    'x-ms-file-change-time'     = 'now'
    'x-ms-file-permission-key'  = $Response.Headers.'x-ms-file-permission-key'[0]
}
Invoke-WebRequest -Authentication 'Bearer' -Headers $Headers -Method 'PUT' -Token $AccessToken -Uri $($ResourceUrl + $FileShareName + '?restype=directory&comp=properties') | Out-Null