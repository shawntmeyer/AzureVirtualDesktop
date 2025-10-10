param 
(       
    [Parameter(Mandatory = $false)]
    [string]$AdminGroupNames,

    [Parameter(Mandatory = $true)]
    [String]$Shares,

    [Parameter(Mandatory = $false)]
    [string]$ShardAzureFilesStorage,
    
    [Parameter(Mandatory = $false)]
    [String]$DomainAccountType = "ComputerAccount",

    [Parameter(Mandatory = $true)]
    [String]$DomainJoinUserPwd,

    [Parameter(Mandatory = $true)]
    [String]$DomainJoinUserPrincipalName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("AES256", "RC4")]
    [String]$KerberosEncryptionType,

    [Parameter(Mandatory = $false)]
    [String]$NetAppServers,

    [Parameter(Mandatory = $false)]
    [String]$OuPath,

    [Parameter(Mandatory = $false)]
    [string]$ResourceManagerUri,

    [Parameter(Mandatory = $false)]
    [String]$StorageAccountPrefix,

    [Parameter(Mandatory = $false)]
    [String]$StorageAccountResourceGroupName,

    [Parameter(Mandatory = $false)]
    [String]$StorageCount,

    [Parameter(Mandatory = $false)]
    [String]$StorageIndex,

    [Parameter(Mandatory = $true)]
    [String]$StorageSolution,

    [Parameter(Mandatory = $false)]
    [String]$StorageSuffix,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [String]$UserGroupNames,

    [Parameter(Mandatory = $false)]
    [string]$UserAssignedIdentityClientId
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

#region Functions

Function ConvertFrom-JsonString {
    [CmdletBinding()]
    param (
        [string]$JsonString,
        [string]$Name    
    )
    If ($JsonString -ne '[]' -and $JsonString -ne $null) {
        [array]$Array = $JsonString.replace('\"', '"') | ConvertFrom-Json
        If ($Array.Length -gt 0) {
            Return $Array
        }
        Else {
            Return $null
        }            
    }
    Else {
        Return $null
    }    
}

Function Get-ADGroupDetails {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$GroupDisplayName,
        [pscredential]$Credential
    )
    $Group = $null
    $Group = Get-ADGroup -Filter "Name -eq '$GroupDisplayName'" -Credential $Credential    
    If ($null -ne $Group) {
        $DomainComponents = ($Group.DistinguishedName -split ',') | Where-Object { $_ -like 'DC=*' }
        $DomainName = ($DomainComponents -replace 'DC=', '') -join '.'
        $Domain = Get-ADDomain -Identity $DomainName -Credential $Credential
        $NetbiosName = $Domain.NetBIOSName
        $GroupName = "$NetbiosName\$($Group.SamAccountName)"
        $GroupSID = $Group.SID
        Return [PSCustomObject]@{
            Name=$GroupName
            SID=$GroupSID
        }
    }
    Return $null
}

Function Update-ACL {
    Param (
        [Parameter(Mandatory = $false)]
        [Array]$AdminGroups,
        [Parameter(Mandatory = $true)]
        [pscredential]$Credential,
        [Parameter(Mandatory = $true)]
        [String]$FileShare,
        [Parameter(Mandatory = $true)]
        [Array]$UserGroups
    )
    # Map Drive
    Write-Output "[Update-ACL]: Mapping Drive to $FileShare"
    New-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Root $FileShare -Credential $Credential | Out-Null
    # Set recommended NTFS permissions on the file share
    Write-Output "[Update-ACL]: Getting Existing ACL for $FileShare"
    $ACL = Get-Acl -Path 'Z:'
    $CreatorOwner = [System.Security.Principal.Ntaccount]("Creator Owner")
    Write-Output "[Update-ACL]: Purging Existing Access Control Entries for 'Creater Owner' from ACL"
    $ACL.PurgeAccessRules($CreatorOwner)
    $AuthenticatedUsers = [System.Security.Principal.Ntaccount]("Authenticated Users")
    Write-Output "[Update-ACL]: Purging Existing Access Control Entries for 'Authenticated Users' from ACL"
    $ACL.PurgeAccessRules($AuthenticatedUsers)
    $Users = [System.Security.Principal.Ntaccount]("Users")
    Write-Output "[Update-ACL]: Purging Existing Access Control Entries for 'Users' from ACL"
    $ACL.PurgeAccessRules($Users)
    If ($AdminGroups.Count -gt 0) {
        ForEach ($Group in $AdminGroups) {
            Write-Output "[Update-ACL]: Adding ACE '$($Group):Full Control' to ACL."
            $Ntaccount = [System.Security.Principal.Ntaccount]("$Group")
            $ACE = ([System.Security.AccessControl.FileSystemAccessRule]::new("$Ntaccount", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"))
            $ACL.SetAccessRule($ACE)
        }
    }

    ForEach ($Group in $UserGroups) {
        Write-Output "[Update-ACL]: Adding ACE '$($Group):Modify (This Folder Only)' to ACL."
        $Ntaccount = [System.Security.Principal.Ntaccount]("$Group")
        $ACE = ([System.Security.AccessControl.FileSystemAccessRule]::new("$Ntaccount", "Modify", "None", "None", "Allow"))
        $ACL.SetAccessRule($ACE)
    }

    Write-Output "[Update-ACL]: Adding ACE 'Creator Owner:Modify (Subfolder and Files Only)' to ACL."
    $ACE = ([System.Security.AccessControl.FileSystemAccessRule]::new("$CreatorOwner", "Modify", "ContainerInherit,ObjectInherit", "InheritOnly", "Allow"))
    $ACL.SetAccessRule($ACE)
    Write-Output "[Update-ACL]: Applying the following ACL to $($FileShare):"
    Write-Output "$($ACL.access | Format-Table | Out-String)"
    $ACL | Set-Acl -Path 'Z:' | Out-Null
    Start-Sleep -Seconds 5 | Out-Null
    $ACL = Get-Acl -Path 'Z:'
    Write-Output "[Update-ACL]: Current ACL of $($FileShare):"
    Write-Output "$($ACL.access | Format-Table | Out-String)"
    # Unmount file share
    Write-Output "[Update-ACL]: Unmapping Drive from $FileShare"
    Remove-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Force | Out-Null
    Start-Sleep -Seconds 5 | Out-Null
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
            'Authorization'           = 'Bearer ' + $AccessToken
            'Content-Type'            = 'application/json'
            'x-ms-date'               = (Get-Date).ToUniversalTime().ToString('R')
            'x-ms-version'            = '2024-11-04'
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
            $DirectoryProps = Invoke-WebRequest -Headers $Headers -Method 'GET' -Uri $GetUri -UseBasicParsing
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

    # Convert Parameters passed as a JSON String to an array and remove any backslashes
    [array]$AdminGroupNames = ConvertFrom-JsonString -JsonString $AdminGroupNames -Name 'AdminGroupNames'
    [array]$Shares = ConvertFrom-JsonString -JsonString $Shares -Name 'Shares'
    [array]$UserGroupNames = ConvertFrom-JsonString -JsonString $UserGroupNames -Name 'UserGroupNames'

    # Check if the Active Directory module is installed
    $RsatInstalled = (Get-WindowsFeature -Name 'RSAT-AD-PowerShell').Installed
    if (!$RsatInstalled) {
        Install-WindowsFeature -Name 'RSAT-AD-PowerShell' | Out-Null
    }
    # Create Domain credential
    $DomainJoinUserName = $DomainJoinUserPrincipalName.Split('@')[0]
    $DomainPassword = ConvertTo-SecureString -String $DomainJoinUserPwd -AsPlainText -Force
    [pscredential]$DomainCredential = New-Object System.Management.Automation.PSCredential ($DomainJoinUserName, $DomainPassword)

    # Get Domain information
    $Domain = Get-ADDomain -Credential $DomainCredential -Current 'LocalComputer'
    Write-Output "Domain Information:"
    Write-Output "DistiguishedName: $($Domain.DistinguishedName)"
    Write-Output "DNSRoot: $($Domain.DNSRoot)"
    Write-Output "NetBIOSName: $($Domain.NetBIOSName)"

    # Get the SamAccountName, SIDs, and Build an SDDL String for all the DisplayNames provided.
    if ($AdminGroupNames.Count -gt 0) {
        [array]$AdminGroups = @()
        $SDDLAdminGroupsString = @()
        Write-Output "Processing AdminGroupNames by searching AD for Groups with the provided display name and returning the SamAccountName and SDDL String"
        ForEach ($DisplayName in $AdminGroupNames) {
            Write-Output "Processing Admin Group: $DisplayName"
            $GroupDetails = $null
            $GroupDetails = Get-ADGroupDetails -GroupDisplayName $DisplayName -Credential $DomainCredential
            If ($null -ne $GroupDetails) {
                Write-Output "Found Group: $($GroupDetails.Name)"
                $AdminGroups += $GroupDetails.Name
                $GroupSID = $GroupDetails.SID
                $SDDLAdminGroupsString += '(A;OICI;FA;;;' + $GroupSID + ')'
            }
            Else {
                Write-Output "Admin Group not found in Active Directory"
            }            
        }
    }

    Write-Output "Processing UserGroupNames by searching AD for Groups with the provided display name and returning the SamAccountName and SDDL String"
    [array]$UserGroups = @()
    [array]$SDDLUserGroupsString = @()
    ForEach ($DisplayName in $UserGroupNames) {
        Write-Output "Processing User Group: $DisplayName"
        $GroupDetails = $null
        $GroupDetails = Get-ADGroupDetails -GroupDisplayName $DisplayName -Credential $DomainCredential
        If ($null -ne $GroupDetails) {
            $GroupSID = $null
            Write-Output "Found Group: $($GroupDetails.Name)"
            $UserGroups += $GroupDetails.Name
            $GroupSID = $GroupDetails.SID
            $SDDLUserGroupsString += '(A;;0x1301bf;;;' + $GroupSID + ')'
        }
        Else {
            Write-Output "User Group not found in Active Directory"
        }    
    }

    Switch ($StorageSolution) {
        'AzureFiles' {
            Write-Output "Processing Azure Files"
            # Convert strings to integers    
            [int]$StCount = $StorageCount.replace('\"', '"')
            [int]$StIndex = $StorageIndex.replace('\"', '"')
            Write-Output "Storage Account Count: $StCount"
            Write-Output "Storage Account Index: $StIndex"
            # Remove any escape characters from strings
            $OuPath = $OuPath.Replace('\"', '"')
            Write-Output "OU Path: $OuPath"
            $ResourceManagerUri = $ResourceManagerUri.Replace('\"', '"')
            Write-Output "ResourceManagerUri: $ResourceManagerUri"
            $StorageAccountPrefix = $StorageAccountPrefix.ToLower().replace('\"', '"')
            Write-Output "Storage Account Prefix: $StorageAccountPrefix"
            $StorageAccountResourceGroupName = $StorageAccountResourceGroupName.Replace('\"', '"')
            Write-Output "Storage Account Resource Group Name: $StorageAccountResourceGroupName"
            $SubscriptionId = $SubscriptionId.replace('\"', '"')
            Write-Output "Subscription Id: $SubscriptionId"            
            $UserAssignedIdentityClientId = $UserAssignedIdentityClientId.replace('\"', '"')
            Write-Output "User Assigned Identity Client Id: $UserAssignedIdentityClientId"
            # Set the suffix for the Azure Files
            $FilesSuffix = ".file.$($StorageSuffix.Replace('\"', '"'))"
            Write-Output "Files Suffix: $FilesSuffix"
            # Fix the resource manager URI since only AzureCloud contains a trailing slash
            $ResourceManagerUriFixed = if ($ResourceManagerUri[-1] -eq '/') { $ResourceManagerUri.Substring(0, $ResourceManagerUri.Length - 1) } else { $ResourceManagerUri }
            # Get an access token for Azure resources
            Write-Output "Getting an access token for Azure resources"
            $AzureManagementAccessToken = (Invoke-RestMethod `
                    -Headers @{Metadata = "true" } `
                    -Uri $('http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + $ResourceManagerUriFixed + '&client_id=' + $UserAssignedIdentityClientId)).access_token
            # Set header for Azure Management API
            $AzureManagementHeader = @{
                'Content-Type'  = 'application/json'
                'Authorization' = 'Bearer ' + $AzureManagementAccessToken
            }   
            for ($i = 0; $i -lt $StCount; $i++) {
                # Build the Storage Account Name and FQDN
                $StorageAccountName = $StorageAccountPrefix + ($i + $StIndex).ToString().PadLeft(2, '0')
                Write-Output "Processing Storage Account Name: $StorageAccountName"
                $FileServer = '\\' + $StorageAccountName + $FilesSuffix
                $ResourceUrl = 'https://' + $StorageAccountName + $FilesSuffix
                    
                # Get / create kerberos key for Azure Storage Account
                Write-Output "Getting Kerberos Key for Azure Storage Account"
                $KerberosKey = ((Invoke-RestMethod `
                            -Headers $AzureManagementHeader `
                            -Method 'POST' `
                            -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/listKeys?api-version=2023-05-01&$expand=kerb')).keys | Where-Object { $_.Keyname -contains 'kerb1' }).Value
                
                if (!$KerberosKey) {
                    Write-Output "Kerberos Key not found, Generating a new key"
                    $null = Invoke-RestMethod `
                        -Body (@{keyName = 'kerb1' } | ConvertTo-Json) `
                        -Headers $AzureManagementHeader `
                        -Method 'POST' `
                        -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/regenerateKey?api-version=2023-05-01')
                    $Key = ((Invoke-RestMethod `
                                -Headers $AzureManagementHeader `
                                -Method 'POST' `
                                -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/listKeys?api-version=2023-05-01&$expand=kerb')).keys | Where-Object { $_.Keyname -contains 'kerb1' }).Value
                } 
                else {
                    Write-Output "Kerberos Key found"
                    $Key = $KerberosKey
                }
                # Creates a password for the Azure Storage Account in AD using the Kerberos key
                Write-Output "Creating a password for the Azure Storage Account in AD using the Kerberos key"
                $ComputerPassword = ConvertTo-SecureString -String $Key.Replace("'", "") -AsPlainText -Force  
                # Create the SPN value for the Azure Storage Account; attribute for computer object in AD
                Write-Output "Creating the SPN value for the Azure Storage Account" 
                $SPN = 'cifs/' + $StorageAccountName + $FilesSuffix
                # Create the Description value for the Azure Storage Account; attribute for computer object in AD 
                $Description = "Computer account object for Azure storage account $($StorageAccountName)."

                # Create the AD computer object for the Azure Storage Account
                Write-Output "Searching for existing computer account object for Azure Storage Account"
                $Computer = Get-ADComputer -Credential $DomainCredential -Filter { Name -eq $StorageAccountName }
                if ($Computer) {
                    Write-Output "Computer account object for Azure Storage Account found, removing the existing object"
                    Remove-ADComputer -Credential $DomainCredential -Identity $StorageAccountName -Confirm:$false
                }
                Else {
                    Write-Output "Computer account object for Azure Storage Account not found"
                }
                Write-Output "Creating the AD computer object for the Azure Storage Account"
                $ComputerObject = New-ADComputer -Credential $DomainCredential -Name $StorageAccountName -Path $OuPath -ServicePrincipalNames $SPN -AccountPassword $ComputerPassword -Description $Description -PassThru
                # Update the Azure Storage Account with the domain join 'INFO'
                Write-Output "Updating the Azure Storage Account with the domain join 'INFO'"
                $SamAccountName = switch ($KerberosEncryptionType) {
                    'AES256' { $StorageAccountName }
                    'RC4' { $ComputerObject.SamAccountName }
                }    
                $Body = (@{
                        properties = @{
                            azureFilesIdentityBasedAuthentication = @{
                                activeDirectoryProperties = @{
                                    accountType       = 'Computer'
                                    azureStorageSid   = $ComputerObject.SID.Value
                                    domainGuid        = $Domain.ObjectGUID.Guid
                                    domainName        = $Domain.DNSRoot
                                    domainSid         = $Domain.DomainSID.Value
                                    forestName        = $Domain.Forest
                                    netBiosDomainName = $Domain.NetBIOSName
                                    samAccountName    = $samAccountName
                                }
                                directoryServiceOptions   = 'AD'
                            }
                        }
                    } | ConvertTo-Json -Depth 6 -Compress)  

                $null = Invoke-RestMethod `
                    -Body $Body `
                    -Headers $AzureManagementHeader `
                    -Method 'PATCH' `
                    -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '?api-version=2023-05-01')             
                
                # Enable AES256 encryption if selected
                if ($KerberosEncryptionType -eq 'AES256') {
                    Write-Output "Setting the Kerberos encryption to $KerberosEncryptionType the computer object"
                    # Set the Kerberos encryption on the computer object
                    $DistinguishedName = 'CN=' + $StorageAccountName + ',' + $OuPath
                    Set-ADComputer -Credential $DomainCredential -Identity $DistinguishedName -KerberosEncryptionType 'AES256' | Out-Null
                    
                    # Reset the Kerberos key on the Storage Account
                    Write-Output "Resetting the kerb1 key on the Storage Account"
                    $null = Invoke-RestMethod `
                        -Body (@{keyName = 'kerb1' } | ConvertTo-Json) `
                        -Headers $AzureManagementHeader `
                        -Method 'POST' `
                        -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/regenerateKey?api-version=2023-05-01')
                    
                    Write-Output "Resetting the kerb2 key on the Storage Account"
                    $null = Invoke-RestMethod `
                        -Body (@{keyName = 'kerb2' } | ConvertTo-Json) `
                        -Headers $AzureManagementHeader `
                        -Method 'POST' `
                        -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/regenerateKey?api-version=2023-05-01')

                    $Key = ((Invoke-RestMethod `
                                -Headers $AzureManagementHeader `
                                -Method 'POST' `
                                -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/listKeys?api-version=2023-05-01&$expand=kerb')).keys | Where-Object { $_.Keyname -contains 'kerb1' }).Value
                
                    # Update the password on the computer object with the new Kerberos key on the Storage Account
                    Write-Output "Updating the password on the computer object with the new Kerberos key (kerb1) on the Storage Account"
                    $NewPassword = ConvertTo-SecureString -String $Key -AsPlainText -Force
                    Set-ADAccountPassword -Credential $DomainCredential -Identity $DistinguishedName -Reset -NewPassword $NewPassword | Out-Null
                }
                $SDDLStartString = 'O:BAG:SYD:PAI(A;OICIIO;0x1301bf;;;CO)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)'

                if ($ShardAzureFilesStorage -eq 'true') {
                    foreach ($Share in $Shares) {
                        $UserGroup = $null
                        [array]$UserGroup += $UserGroups[$i]
                        Write-Output "Processing File Share: $FileShare with UserGroup = $($UserGroups[$i])"
                        if ($AdminGroups.Count -gt 0) {
                            Write-Output "Admin Groups provided, executing Update-ACL with Admin Groups"
                            $SDDLString = ($SDDLStartString + $SDDLAdminGroupsString + $SDDLUserGroupsString[$i]) -replace ' ', ''
                        }
                        Else {
                            Write-Output "Admin Groups not provided, executing Update-ACL without Admin Groups"
                            $SDDLString = ($SDDLStartString + $SDDLUserGroupsString) -replace ' ', ''
                        }
                        Set-AzureFileSharePermissions -FileShareName $Share -StorageAccountName $StorageAccountName -StorageSuffix $StorageSuffix -SDDLString $SDDLString -ClientId $UserAssignedIdentityClientId
                    }
                }
                Else {
                    foreach ($Share in $Shares) {
                        $FileShare = $FileServer + '\' + $Share
                        Write-Output "Processing File Share: $FileShare"
                        if ($AdminGroups.Count -gt 0) {
                            Write-Output "Admin Groups provided, executing Update-ACL with Admin Groups"
                            $SDDLString = ($SDDLStartString + $SDDLAdminGroupsString + $SDDLUserGroupsString) -replace ' ', ''
                        }
                        Else {
                            Write-Output "Admin Groups not provided, executing Update-ACL without Admin Groups"
                            $SDDLString = ($SDDLStartString + $SDDLUserGroupsString) -replace ' ', ''
                        }
                        Set-AzureFileSharePermissions -FileShareName $Share -StorageAccountName $StorageAccountName -StorageSuffix $StorageSuffix -SDDLString $SDDLString -ClientId $UserAssignedIdentityClientId
                    }
                }
            }
        }
        'AzureNetAppFiles' {
            Write-Output "Processing Azure NetApp Files"        

            [array]$NetAppServers = ConvertFrom-JsonString -JsonString $NetAppServers -Name 'NetAppServers'

            $ProfileShare = "\\$($NetAppServers[0])\$($Shares[0])"
            Write-Output "Processing Profile Share: $ProfileShare"
            if ($AdminGroups.Count -gt 0) {
                Write-Output "Admin Groups and UserGroups provided, executing Update-ACL with Admin Groups and UserGroups"
                Update-ACL -AdminGroups $AdminGroups -Credential $DomainCredential -FileShare $ProfileShare -UserGroups $UserGroups
            }
            Else {
                Write-Output "UserGroups provided, executing Update-ACL with UserGroups only"
                Update-ACL -Credential $DomainCredential -FileShare $ProfileShare -UserGroups $UserGroups
            }
            
            If ($NetAppServers.Count -gt 1 -and $Shares.Count -gt 1) {
                $OfficeShare = "\\" + $NetAppServers[1] + "\" + $Shares[1]
                Write-Output "Processing Office Share: $OfficeShare"
                If ($AdminGroups.Count -gt 0 -and $UserGroups.Count -gt 0) {
                    Write-Output "Admin Groups and UserGroups provided, executing Update-ACL with Admin Groups and UserGroups"
                    Update-ACL -AdminGroups $AdminGroups -Credential $DomainCredential -FileShare $OfficeShare -UserGroups $UserGroups
                }
                ElseIf ($AdminGroups.Count -gt 0 -and $UserGroups.Count -eq 0) {
                    Write-Output "Admin Groups provided, executing Update-ACL with Admin Groups only"
                    Update-ACL -AdminGroups $AdminGroups -Credential $DomainCredential -FileShare $OfficeShare
                }
                ElseIf ($AdminGroups.Count -eq 0 -and $UserGroups.Count -gt 0) {
                    Write-Output "UserGroups provided, executing Update-ACL with UserGroups only"
                    Update-ACL -Credential $DomainCredential -FileShare $OfficeShare -UserGroups $UserGroups
                }
                Else {
                    Write-Output "No Admin Groups or UserGroups provided, executing Update-ACL without Admin Groups or UserGroups"
                    Update-ACL -Credential $DomainCredential -FileShare $OfficeShare
                }
            }
        }
    } 
}
catch {
    throw
}
#endregion Main Script