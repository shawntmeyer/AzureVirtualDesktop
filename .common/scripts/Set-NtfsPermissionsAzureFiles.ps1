<#
.SYNOPSIS
    Sets NTFS permissions on Azure File Shares using REST API and SDDL strings.

.DESCRIPTION
    This script configures NTFS permissions on Azure File Shares by:
    1. Converting group names/objects from JSON to Security Identifiers (SIDs)
    2. Building SDDL (Security Descriptor Definition Language) strings
    3. Creating Azure Storage Account computer objects in Active Directory
    4. Setting permissions via Azure Files REST API

    Supports both single and sharded storage account scenarios.

.PARAMETER AdminGroups
    JSON array of administrator groups (strings or objects with GroupName/DomainName/SID properties)

.PARAMETER Shares
    JSON array of file share names to configure

.PARAMETER ShardAzureFilesStorage
    Boolean string ("true"/"false") indicating if storage accounts are sharded per user group

.PARAMETER StorageAccountPrefix
    Prefix for storage account names (e.g., "stavd")

.PARAMETER StorageCount
    Number of storage accounts to process

.PARAMETER StorageIndex
    Starting index for storage account numbering

.PARAMETER StorageSuffix
    Storage endpoint suffix (e.g., "core.windows.net")

.PARAMETER UserGroups
    JSON array of user groups (strings or objects with groupName/domainName/sid properties)

.PARAMETER UserAssignedIdentityClientId
    Client ID of the user-assigned managed identity for Azure API authentication

.EXAMPLE
    .\Set-NtfsPermissions-sa.ps1 -Shares '["profiles","office"]' -UserGroups '["Domain Users"]'

.NOTES
    Requires:
    - Active Directory PowerShell module
    - User-assigned managed identity with appropriate permissions
    - Storage accounts with Azure Files enabled
#>

param 
(       
    [string]$AdminGroupNames,

    [String]$Shares,

    [string]$ShardAzureFilesStorage,    

    [String]$StorageAccountPrefix,

    [String]$StorageCount,

    [String]$StorageIndex,

    [String]$StorageSuffix,

    [string]$UserAssignedIdentityClientId,
    
    [String]$UserGroupNames
)

# Configure error handling and output preferences
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

#region Functions

Function Convert-GroupToSID {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$DomainName,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]$GroupName
    )
    Begin {
        [array]$groupSIDs = @()
    }
    Process {
        ForEach ($Group in $GroupName) {
            [string]$groupSID = ''
            Try {
                $groupSID = (New-Object System.Security.Principal.NTAccount("$Group")).Translate([System.Security.Principal.SecurityIdentifier]).Value           
            }
            Catch {
                Try {
                    $groupSID = (New-Object System.Security.Principal.NTAccount($DomainName, "$Group")).Translate([System.Security.Principal.SecurityIdentifier]).Value
                }
                Catch {
                    throw "Failed to convert group name $Group' to SID."
                }
            }
            if ($groupSID) {
                $groupSIDs += $groupSID
            }
        }
        Write-Output -InputObject $groupSIDs
    }
}

Function Set-AzureFileSharePermissions {
    param(
        [string]$ClientId,    
        [string]$FileShareName,
        [string]$StorageAccountName,
        [string]$StorageSuffix,
        [string]$SDDLString
    )

    try {
        Write-Output "[Set-AzureFileSharePermissions]: Setting NTFS permissions on Azure File Share: $FileShareName"        
        $ResourceUrl = 'https://' + $StorageAccountName + '.file.' + $StorageSuffix + '/'
        Write-Output "[Set-AzureFileSharePermissions]: Resource URL: $ResourceUrl"
        # Get access token for Azure Files
        Write-Output "[Set-AzureFileSharePermissions]: Getting access token for Azure File Storage Account"
        $AccessToken = (Invoke-RestMethod -Headers @{Metadata = "true" } -Uri $('http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + $ResourceUrl + '&client_id=' + $ClientId)).access_token

        # Step 1: Create Permission - Convert SDDL to permission key
        Write-Output "[Set-AzureFileSharePermissions]: Creating permission key from SDDL"
        $Headers = @{
            'Authorization'            = 'Bearer ' + $AccessToken
            'Content-Type'             = 'application/json'
            'x-ms-date'                = (Get-Date).ToUniversalTime().ToString('R')
            'x-ms-version'             = '2024-11-04'
            'x-ms-file-request-intent' = 'backup'
        }
        
        $Body = @{
            permission = $SDDLString
            format     = 'sddl'
        } | ConvertTo-Json
        
        $Uri = $($ResourceUrl + $FileShareName + '?restype=share&comp=filepermission')
        Write-Output "[Set-AzureFileSharePermissions]: Creating permission with URI: $Uri"

        $Response = Invoke-WebRequest -Body $Body -Headers $Headers -Method 'PUT' -Uri $Uri -UseBasicParsing
        $PermissionKey = $Response.Headers["x-ms-file-permission-key"]
        
        if (-not $PermissionKey) {
            throw "Failed to create permission key. Response Headers: $($Response.Headers | ConvertTo-Json -Depth 3)"
        }
        
        Write-Output "[Set-AzureFileSharePermissions]: Permission key created: $PermissionKey"

        # Step 2: Get Directory Properties to ensure directory exists
        Write-Output "[Set-AzureFileSharePermissions]: Getting directory properties"
        $Headers = @{
            'Authorization'            = 'Bearer ' + $AccessToken
            'x-ms-version'             = '2024-11-04'
            'x-ms-date'                = (Get-Date).ToUniversalTime().ToString('R')
            'x-ms-file-request-intent' = 'backup'
        }
        
        $GetUri = $($ResourceUrl + $FileShareName + '?restype=directory')
        try {
            Invoke-WebRequest -Headers $Headers -Method 'GET' -Uri $GetUri -UseBasicParsing | Out-Null
            Write-Output "[Set-AzureFileSharePermissions]: Directory properties retrieved successfully"
        }
        catch {
            Write-Output "[Set-AzureFileSharePermissions]: Directory may not exist or error getting properties: $($_.Exception.Message)"
        }

        # Step 3: Set Directory Properties with the permission key
        Write-Output "[Set-AzureFileSharePermissions]: Setting directory properties with permission key"
        $Headers = @{
            'Authorization'             = 'Bearer ' + $AccessToken
            'x-ms-date'                 = (Get-Date).ToUniversalTime().ToString('R')
            'x-ms-version'              = '2024-11-04'
            'x-ms-file-request-intent'  = 'backup'
            'x-ms-file-creation-time'   = 'preserve'
            'x-ms-file-last-write-time' = 'preserve'
            'x-ms-file-change-time'     = 'now'
            'x-ms-file-permission-key'  = $PermissionKey
        }
        
        $SetUri = $($ResourceUrl + $FileShareName + '?restype=directory&comp=properties')
        Write-Output "[Set-AzureFileSharePermissions]: Setting properties with URI: $SetUri"
        
        Invoke-WebRequest -Headers $Headers -Method 'PUT' -Uri $SetUri -UseBasicParsing | Out-Null
        Write-Output "[Set-AzureFileSharePermissions]: Successfully set NTFS permissions on file share root"
    }
    catch {
        Write-Error "[Set-AzureFileSharePermissions]: Failed to set NTFS permissions: $($_.Exception.Message)"
        Write-Error "[Set-AzureFileSharePermissions]: Full error: $($_ | Out-String)"
        throw
    }
}

#endregion Functions

#region Main Script
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $DefaultDomain = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
    Write-Output "Default Domain: $DefaultDomain"    
    # Convert Admin Groups to SIDs if provided
    [array]$AdminGroupSIDs = @()
    if ($AdminGroupNames -and $AdminGroupNames.Trim() -and $AdminGroupNames.Trim() -ne '[]') {
        $AdminGroupNamesArray = $AdminGroupNames.replace('\"', '"') | ConvertFrom-Json
        if ($AdminGroupNamesArray -and $AdminGroupNamesArray.Count -gt 0) {
            $AdminGroupSIDs = Convert-GroupToSID -DomainName $DefaultDomain -GroupName $AdminGroupNamesArray
        }
    }
    
    [array]$Shares = $Shares.Replace('\"', '"') | ConvertFrom-Json
    
    # Convert User Groups to SIDs if provided
    [array]$UserGroupSIDs = @()
    if ($UserGroupNames -and $UserGroupNames.Trim() -and $UserGroupNames.Trim() -ne '[]') {
        $UserGroupNamesArray = $UserGroupNames.replace('\"', '"') | ConvertFrom-Json
        if ($UserGroupNamesArray -and $UserGroupNamesArray.Count -gt 0) {
            $UserGroupSIDs = Convert-GroupToSID -DomainName $DefaultDomain -GroupName $UserGroupNamesArray
        }
    }
    # Base SDDL string with default permissions:
    # O:BA = Owner: Built-in Administrators
    # G:SY = Group: System
    # D:PAI = DACL: Protected, Auto-Inherited
    # (A;OICIIO;0x1301bf;;;CO) = Allow Object/Container Inherit, Creator Owner: Modify
    # (A;OICI;FA;;;SY) = Allow Object/Container Inherit, System: Full Access
    # (A;OICI;FA;;;BA) = Allow Object/Container Inherit, Built-in Administrators: Full Access
    $SDDLStartString = 'O:BAG:SYD:PAI(A;OICIIO;0x1301bf;;;CO)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)'
    $SDDLBuiltInUsersString = '(A;;0x1301bf;;;BU)'

    # Build SDDL entries for admin groups if provided
    if ($AdminGroupSIDs.Count -gt 0) {
        $SDDLAdminGroupsString = @()
        ForEach ($GroupSID in $AdminGroupSIDs) {    
            $SDDLAdminGroupsString += '(A;OICI;FA;;;' + $GroupSID + ')'
        }
    }

    # Build SDDL entries for user groups if provided
    if ($UserGroupSIDs.Count -gt 0) {
        $SDDLUserGroupsString = @()
        ForEach ($GroupSID in $UserGroupSIDs) {    
            # Add ACE (Access Control Entry) for user group with Modify permissions
            # (A;;0x1301bf;;;SID) = Allow, Modify rights (0x1301bf), for specific SID
            $SDDLUserGroupsString += '(A;;0x1301bf;;;' + $GroupSID + ')'
        }
    }
   
    # Parse and clean configuration parameters
    [int]$StCount = $StorageCount.replace('\"', '"')  # Number of storage accounts to process
    [int]$StIndex = $StorageIndex.replace('\"', '"')  # Starting index for storage account naming
    $StorageAccountPrefix = $StorageAccountPrefix.ToLower().replace('\"', '"')  # Storage account name prefix     
    $UserAssignedIdentityClientId = $UserAssignedIdentityClientId.replace('\"', '"')  # Managed identity for Azure API calls    
    # Build Azure Files endpoint suffix
    $FilesSuffix = ".file.$($StorageSuffix.Replace('\"', '"'))" 
    # Process each storage account in the range
    for ($i = 0; $i -lt $StCount; $i++) {
        # Generate storage account name with zero-padded index (e.g., "stavd01", "stavd02")
        $StorageAccountName = $StorageAccountPrefix + ($i + $StIndex).ToString().PadLeft(2, '0')
        Write-Output "Processing Storage Account Name: $StorageAccountName"
        
        # Build UNC path and HTTPS URL for the storage account
        $FileServer = '\\' + $StorageAccountName + $FilesSuffix  # UNC: \\stavd01.file.core.windows.net
        $ResourceUrl = 'https://' + $StorageAccountName + $FilesSuffix  # HTTPS: https://stavd01.file.core.windows.net
        if ($AdminGroups.Count -eq 0 -and $UsersGroups.Count -eq 0) {
            Write-Output "No Admin or User Groups provided, Setting default permissions for $StorageAccountName"
            $SDDLString = ($SDDLStartString + $SDDLUserGroupsString) -replace ' ', ''
        }
        Elseif ($ShardAzureFilesStorage -eq 'true') {
            # Check if storage is sharded (different user groups per storage account)
            # SHARDED MODE: Each storage account gets a specific user group
            foreach ($Share in $Shares) {
                if ($AdminGroups.Count -gt 0 -and $UsersGroups.Count -gt 0) {
                    Write-Output "Admin Groups provided, executing Update-ACL with Admin Groups"
                    # Build SDDL with admin groups + specific user group for this storage account index
                    $SDDLString = ($SDDLStartString + $SDDLAdminGroupsString + $SDDLUserGroupsString[$i]) -replace ' ', ''
                }
                Else {
                    Write-Output "Admin Groups not provided, executing Update-ACL without Admin Groups"
                    # Build SDDL with only the specific user group for this storage account index
                    $SDDLString = ($SDDLStartString + $SDDLUserGroupsString[$i]) -replace ' ', ''
                }                
            }
        }
        Else {
            # NON-SHARDED MODE: All storage accounts get the same user groups
            foreach ($Share in $Shares) {
                $FileShare = $FileServer + '\' + $Share
                Write-Output "Processing File Share: $FileShare"
                if ($AdminGroups.Count -gt 0 -and $UsersGroups.Count -gt 0) {
                    Write-Output "Admin Groups provided, executing Update-ACL with Admin Groups"
                    # Build SDDL with admin groups + all user groups
                    $SDDLString = ($SDDLStartString + $SDDLAdminGroupsString + $SDDLUserGroupsString) -replace ' ', ''
                }
                Else {
                    Write-Output "Admin Groups not provided, executing Update-ACL without Admin Groups"
                    # Build SDDL with only user groups
                    $SDDLString = ($SDDLStartString + $SDDLUserGroupsString) -replace ' ', ''
                }                
            }
            # Apply permissions to the file share using Azure Files REST API
            Set-AzureFileSharePermissions -FileShareName $Share -StorageAccountName $StorageAccountName -StorageSuffix $StorageSuffix -SDDLString $SDDLString -ClientId $UserAssignedIdentityClientId
        }
    }
}       
catch {
    throw
}
#endregion Main Script