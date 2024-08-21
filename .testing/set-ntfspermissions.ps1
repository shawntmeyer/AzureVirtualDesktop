param 
(
    [Parameter(Mandatory = $false)]
    [string]$AdminGroupDomainNames = '["CORP"]',

    [Parameter(Mandatory = $false)]
    [string]$AdminGroupSamAccountNames = '["Azure CBA Users"]',
    
    [Parameter(Mandatory = $false)]
    [String]$DomainAccountType = "ComputerAccount",

    [Parameter(Mandatory)]
    [String]$DomainJoinUserPassword = '1qaz@WSX1qaz@WSX',

    [Parameter(Mandatory)]
    [String]$DomainJoinUserPrincipalName = 'corpadmin@corp.shmeyer.onmicrosoft.us',

    [Parameter(Mandatory = $false)]
    [String]$ActiveDirectorySolution = 'ActiveDirectoryDomainServices',

    [Parameter(Mandatory)]
    [String]$FslogixContainerType = 'ProfileContainer',

    [Parameter(Mandatory = $false)]
    [ValidateSet("AES256", "RC4")]
    [String]$KerberosEncryptionType = 'AES256',

    [Parameter(Mandatory = $false)]
    [String]$Netbios = 'corp',

    [Parameter(Mandatory = $false)]
    [String]$OuPath = 'OU=USGVA,OU=AVD,OU=Computers,OU=Azure,DC=corp,DC=shmeyer,DC=onmicrosoft,DC=us',

    [Parameter(Mandatory = $false)]
    [string]$ResourceManagerUri = 'https://management.usgovcloudapi.net',

    [Parameter(Mandatory = $false)]
    [String]$SmbServerLocation,

    [Parameter(Mandatory = $false)]
    [String]$StorageAccountPrefix = 'adds6pcva',

    [Parameter(Mandatory = $false)]
    [String]$StorageAccountResourceGroupName = 'rg-avd-adds6-storage-va',

    [Parameter(Mandatory = $false)]
    [String]$StorageCount = '1',

    [Parameter(Mandatory = $false)]
    [String]$StorageIndex = '1',

    [Parameter(Mandatory)]
    [String]$StorageSolution = 'AzureFiles',

    [Parameter(Mandatory = $false)]
    [String]$StorageSuffix = 'core.usgovcloudapi.net',

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = '70c1bb3a-115f-4300-becd-5f74200999bb',

    [Parameter(Mandatory = $false)]
    [string]$UserAssignedIdentityClientId = 'a9d9ee7d-beff-4d3d-9da1-cfb9d9e20229'
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

try {

    # Convert Admin Group Parameters from a String to an array
    [array]$Domains = $AdminGroupDomainNames.replace('\','') | ConvertFrom-Json
    [array]$SamAcccountNames = $AdminGroupSamAccountNames.replace('\','') | ConvertFrom-Json

    # Combine Admin Group Parameters into a single array

    $AdminGroups = @()
    for ($i = 0; $i -lt $Domains.Length; $i++) {
        $AdminGroups += $Domains[$i] + '\' + $SamAcccountNames[$i]
    }
$AdminGroups
    ##############################################################
    #  Install Prerequisites
    ##############################################################
    # Install Active Directory PowerShell module
    if ($StorageSolution -eq 'AzureNetAppFiles' -or ($StorageSolution -eq 'AzureFiles' -and $ActiveDirectorySolution -eq 'ActiveDirectoryDomainServices')) {
        $RsatInstalled = (Get-WindowsFeature -Name 'RSAT-AD-PowerShell').Installed
        if (!$RsatInstalled) {
            Install-WindowsFeature -Name 'RSAT-AD-PowerShell' | Out-Null
        }
    }

    ##############################################################
    #  Variables
    ##############################################################

    # Selects the appropriate share names based on the FSlogixContainerType param from the deployment
    $Shares = switch ($FslogixContainerType) {
        'CloudCacheProfileContainer' { @('profile-containers') }
        'CloudCacheProfileOfficeContainer' { @('office-containers', 'profile-containers') }
        'ProfileContainer' { @('profile-containers') }
        'ProfileOfficeContainer' { @('office-containers', 'profile-containers') }
    }

    if ($StorageSolution -eq 'AzureNetAppFiles' -or ($StorageSolution -eq 'AzureFiles' -and $ActiveDirectorySolution -eq 'ActiveDirectoryDomainServices')) {
        # Create Domain credential
        $DomainUsername = $DomainJoinUserPrincipalName
        $DomainPassword = ConvertTo-SecureString -String $DomainJoinUserPassword -AsPlainText -Force
        [pscredential]$DomainCredential = New-Object System.Management.Automation.PSCredential ($DomainUsername, $DomainPassword)
    
        # Get Domain information
        $Domain = Get-ADDomain -Credential $DomainCredential -Current 'LocalComputer'
        Write-Host "Domain: $Domain"
    }

    if ($StorageSolution -eq 'AzureFiles') {
        $FilesSuffix = '.file.' + $StorageSuffix
Write-Host $FilesSuffix
        # Fix the resource manager URI since only AzureCloud contains a trailing slash
        $ResourceManagerUriFixed = if ($ResourceManagerUri[-1] -eq '/') { $ResourceManagerUri.Substring(0, $ResourceManagerUri.Length - 1) } else { $ResourceManagerUri }

        # Get an access token for Azure resources
        $AzureManagementAccessToken = (Invoke-RestMethod `
                -Headers @{Metadata = "true" } `
                -Uri $('http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + $ResourceManagerUriFixed + '&client_id=' + $UserAssignedIdentityClientId)).access_token

        # Set header for Azure Management API
        $AzureManagementHeader = @{
            'Content-Type'  = 'application/json'
            'Authorization' = 'Bearer ' + $AzureManagementAccessToken
        }
    }

    [int]$StCount = $StorageCount
    [int]$StIndex = $StorageIndex
    ##############################################################
    #  Process Storage Resources
    ##############################################################
    for ($i = 0; $i -lt $StCount; $i++) {
        # Get storage resource details
        switch ($StorageSolution) {
            'AzureNetAppFiles' {
                $Credential = $DomainCredential
                $SmbServerName = (Get-ADComputer -Filter "Name -like 'anf-$SmbServerLocation*'" -Credential $DomainCredential).Name
                $FileServer = '\\' + $SmbServerName + '.' + $Domain.DNSRoot
            }
            'AzureFiles' {
                $StorageAccountName = $StorageAccountPrefix + ($i + $StIndex).ToString()
                Write-Host "Storage Account Name: $StorageAccountName"
                $FileServer = '\\' + $StorageAccountName + $FilesSuffix
                
                # Get the storage account key
                $StorageKey = (Invoke-RestMethod `
                    -Headers $AzureManagementHeader `
                    -Method 'POST' `
                    -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/listKeys?api-version=2023-05-01')).keys[0].value
Write-Host "Storage Key: $StorageKey"
                # Create credential for accessing the storage account
                $StorageUsername = 'Azure\' + $StorageAccountName
                $StoragePassword = ConvertTo-SecureString -String "$($StorageKey)" -AsPlainText -Force
                [pscredential]$StorageKeyCredential = New-Object System.Management.Automation.PSCredential ($StorageUsername, $StoragePassword)
                $Credential = $StorageKeyCredential

                if ($ActiveDirectorySolution -eq 'ActiveDirectoryDomainServices') {
                    # Get / create kerberos key for Azure Storage Account
                    $KerberosKey = ((Invoke-RestMethod `
                        -Headers $AzureManagementHeader `
                        -Method 'POST' `
                        -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/listKeys?api-version=2023-05-01&$expand=kerb')).keys | Where-Object { $_.Keyname -contains 'kerb1' }).Value
                    
                    if (!$KerberosKey) {
                        Invoke-RestMethod `
                            -Body (@{keyName = 'kerb1' } | ConvertTo-Json) `
                            -Headers $AzureManagementHeader `
                            -Method 'POST' `
                            -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/regenerateKey?api-version=2023-05-01')
                        
                        $Key = ((Invoke-RestMethod `
                                -Headers $AzureManagementHeader `
                                -Method 'POST' `
                                -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/listKeys?api-version=2023-05-01&$expand=kerb')).keys | Where-Object { $_.Keyname -contains 'kerb1' }).Value
                        Write-Host "Kerberos Key Generated: $key"
                            } 
                    else {
                        $Key = $KerberosKey
                    }

                    # Creates a password for the Azure Storage Account in AD using the Kerberos key
                    $ComputerPassword = ConvertTo-SecureString -String $Key.Replace("'", "") -AsPlainText -Force
Write-Host "Computer Password: $ComputerPassword"
                    # Create the SPN value for the Azure Storage Account; attribute for computer object in AD 
                    $SPN = 'cifs/' + $StorageAccountName + $FilesSuffix

                    # Create the Description value for the Azure Storage Account; attribute for computer object in AD 
                    $Description = "Computer account object for Azure storage account $($StorageAccountName)."

                    # Create the AD computer object for the Azure Storage Account
                    $Computer = Get-ADComputer -Credential $DomainCredential -Filter { Name -eq $StorageAccountName }
                    if ($Computer) {
                        Remove-ADComputer -Credential $DomainCredential -Identity $StorageAccountName -Confirm:$false
                    }
                    $ComputerObject = New-ADComputer -Credential $DomainCredential -Name $StorageAccountName -Path $OuPath -ServicePrincipalNames $SPN -AccountPassword $ComputerPassword -Description $Description -PassThru

                    # Update the Azure Storage Account with the domain join 'INFO'
                    $SamAccountName = switch ($KerberosEncryptionType) {
                        'AES256' { $StorageAccountName }
                        'RC4' { $ComputerObject.SamAccountName }
                    }

                    Invoke-RestMethod `
                        -Body (@{properties = @{azureFilesIdentityBasedAuthentication = @{activeDirectoryProperties = @{accountType = 'Computer' }, @{azureStorageSid = $ComputerObject.SID.Value }, @{domainGuid = $Domain.ObjectGUID }, @{domainName = $Domain.DNSRoot }, @{domainSid = $Domain.DomainSID }, @{forestName = $Domain.Forest }, @{netBiosDomainName = $Domain.NetBIOSName }, @{samAccountName = $samAccountName } }, @{directoryServiceOptions = 'AD' } } } | ConvertTo-Json -Depth 5 ) `
                        -Headers $AzureManagementHeader `
                        -Method 'PATCH' `
                        -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '?api-version=2023-05-01')
               
                    # Enable AES256 encryption if selected
                    if ($KerberosEncryptionType -eq 'AES256') {
                        # Set the Kerberos encryption on the computer object
                        $DistinguishedName = 'CN=' + $StorageAccountName + ',' + $OuPath
                        Set-ADComputer -Credential $DomainCredential -Identity $DistinguishedName -KerberosEncryptionType 'AES256' | Out-Null
                        Write-Log -Message "Setting Kerberos AES256 Encryption on the computer object succeeded" -Type 'INFO'
                        
                        # Reset the Kerberos key on the Storage Account
                        Invoke-RestMethod `
                            -Body (@{keyName = 'kerb1' } | ConvertTo-Json) `
                            -Headers $AzureManagementHeader `
                            -Method 'POST' `
                            -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/regenerateKey?api-version=2023-05-01')
                        
                        $Key = (Invoke-RestMethod `
                                -Headers $AzureManagementHeader `
                                -Method 'POST' `
                                -Uri $($ResourceManagerUriFixed + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $StorageAccountResourceGroupName + '/providers/Microsoft.Storage/storageAccounts/' + $StorageAccountName + '/listKeys?api-version=2023-05-01&$expand=kerb') | Where-Object { $_.Keyname -contains 'kerb1' }).Value
                   
                        # Update the password on the computer object with the new Kerberos key on the Storage Account
                        $NewPassword = ConvertTo-SecureString -String $Key -AsPlainText -Force
                        Set-ADAccountPassword -Credential $DomainCredential -Identity $DistinguishedName -Reset -NewPassword $NewPassword | Out-Null
                    }
                }
            }
        }
        
        foreach ($Share in $Shares) {
            # Mount file share
            $FileShare = $FileServer + '\' + $Share
            New-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Root $FileShare -Credential $Credential | Out-Null
            # Set recommended NTFS permissions on the file share
            $ACL = Get-Acl -Path 'Z:'
            $CreatorOwner = New-Object System.Security.Principal.Ntaccount ("Creator Owner")
            $ACL.PurgeAccessRules($CreatorOwner)
            $AuthenticatedUsers = New-Object System.Security.Principal.Ntaccount ("Authenticated Users")
            $ACL.PurgeAccessRules($AuthenticatedUsers)
            $Users = New-Object System.Security.Principal.Ntaccount ("Users")
            $ACL.PurgeAccessRules($Users)
            $ErrorActionPreference = 'SilentlyContinue'
            ForEach($AdminGroup in $AdminGroups) {
                $ShareAdmins = New-Object System.Security.Principal.Ntaccount ("$AdminGroup")
                $AdminACL = New-Object System.Security.AccessControl.FileSystemAccessRule("$ShareAdmins", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                $ACL.AddAccessRule($AdminACL)
            }
            $ErrorActionPreference = 'Stop'
            $DomainUsers = New-Object System.Security.AccessControl.FileSystemAccessRule("Domain Users", "Modify", "None", "None", "Allow")
            $ACL.SetAccessRule($DomainUsers)
            $CreatorOwner = New-Object System.Security.AccessControl.FileSystemAccessRule("Creator Owner", "Modify", "ContainerInherit,ObjectInherit", "InheritOnly", "Allow")
            $ACL.AddAccessRule($CreatorOwner)
            $ACL | Set-Acl -Path 'Z:' | Out-Null

            # Unmount file share
            Remove-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Force | Out-Null
            Start-Sleep -Seconds 5 | Out-Null
        }
    }
}
catch {
    throw
}