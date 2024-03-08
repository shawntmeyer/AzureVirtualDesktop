param 
(
    [Parameter(Mandatory)]
    [String]$ClientId,

    [Parameter(Mandatory=$false)]
    [String]$DomainAccountType = "ComputerAccount",

    [Parameter(Mandatory)]
    [String]$DomainJoinUserPassword,

    [Parameter(Mandatory)]
    [String]$DomainJoinUserPrincipalName,

    [Parameter(Mandatory=$false)]
    [String]$ActiveDirectorySolution,

    [Parameter(Mandatory=$false)]
    [String]$Environment,

    [Parameter(Mandatory)]
    [String]$FslogixContainerType,

    [Parameter(Mandatory=$false)]
    [ValidateSet("AES256","RC4")]
    [String]$KerberosEncryptionType,

    [Parameter(Mandatory=$false)]
    [String]$Netbios,

    [Parameter(Mandatory=$false)]
    [String]$OuPath,

    [Parameter(Mandatory=$false)]
    [String]$ResourceNameSuffix,

    [Parameter(Mandatory)]
    [String]$SecurityPrincipalNames,

    [Parameter(Mandatory=$false)]
    [String]$SmbServerLocation,

    [Parameter(Mandatory=$false)]
    [String]$StorageAccountPrefix,

    [Parameter(Mandatory=$false)]
    [String]$StorageAccountResourceGroupName,

    [Parameter(Mandatory=$false)]
    [Int]$StorageCount,

    [Parameter(Mandatory=$false)]
    [Int]$StorageIndex,

    [Parameter(Mandatory)]
    [String]$StorageSolution,

    [Parameter(Mandatory=$false)]
    [String]$StorageSuffix,

    [Parameter(Mandatory=$false)]
    [String]$SubscriptionId,

    [Parameter(Mandatory=$false)]
    [String]$TenantId
)

function Write-Log
{
    param(
        [parameter(Mandatory)]
        [string]$Message,
        
        [parameter(Mandatory)]
        [string]$Type
    )
    $Path = 'C:\cse.txt'
    if(!(Test-Path -Path $Path))
    {
        New-Item -Path C:\ -Name cse.txt | Out-Null
    }
    $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
    $Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
    $Entry | Out-File -FilePath $Path -Append
}

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

try 
{
    ##############################################################
    #  Install Prerequisites
    ##############################################################
    # Install Active Directory PowerShell module
    if($StorageSolution -eq 'AzureNetAppFiles' -or ($StorageSolution -eq 'AzureFiles' -and $ActiveDirectorySolution -eq 'ActiveDirectoryDomainServices'))
    {
        $RsatInstalled = (Get-WindowsFeature -Name 'RSAT-AD-PowerShell').Installed
        if(!$RsatInstalled)
        {
            Install-WindowsFeature -Name 'RSAT-AD-PowerShell' | Out-Null
            Write-Log -Message "Installation of the AD module succeeded" -Type 'INFO'
        }
        else
        {
            Write-Log -Message "AD module already exists" -Type 'INFO'   
        }
    }


    ##############################################################
    #  Variables
    ##############################################################
    # Convert Security Principal Names from a JSON array to a PowerShell array
    [array]$SecurityPrincipalNames = $SecurityPrincipalNames.Replace("'",'"') | ConvertFrom-Json
    Write-Log -Message "Security Principal Names:" -Type 'INFO'
    $SecurityPrincipalNames | Add-Content -Path 'C:\cse.txt' -Force | Out-Null

    # Selects the appropriate share names based on the FSlogixContainerType param from the deployment
    $Shares = switch($FslogixContainerType)
    {
        'CloudCacheProfileContainer' {@('profile-containers')}
        'CloudCacheProfileOfficeContainer' {@('office-containers','profile-containers')}
        'ProfileContainer' {@('profile-containers')}
        'ProfileOfficeContainer' {@('office-containers','profile-containers')}
    }

    if($StorageSolution -eq 'AzureNetAppFiles' -or ($StorageSolution -eq 'AzureFiles' -and $ActiveDirectorySolution -eq 'ActiveDirectoryDomainServices'))
    {
        # Create Domain credential
        $DomainUsername = $DomainJoinUserPrincipalName
        $DomainPassword = ConvertTo-SecureString -String $DomainJoinUserPassword -AsPlainText -Force
        [pscredential]$DomainCredential = New-Object System.Management.Automation.PSCredential ($DomainUsername, $DomainPassword)
    
        # Get Domain information
        $Domain = Get-ADDomain -Credential $DomainCredential -Current 'LocalComputer'
        Write-Log -Message "Domain information collection succeeded" -Type 'INFO'
    }

    if($StorageSolution -eq 'AzureFiles')
    {
        $FilesSuffix = '.file.' + $StorageSuffix
        Write-Log -Message "Azure Files Suffix = $FilesSuffix" -Type 'INFO'
    }


    ##############################################################
    #  Process Storage Resources
    ##############################################################
    for($i = 0; $i -lt $StorageCount; $i++)
    {
        # Determine Principal for assignment
        $SecurityPrincipalName = $SecurityPrincipalNames[$i]
        $Group = $Netbios + '\' + $SecurityPrincipalName
        Write-Log -Message "Group for NTFS Permissions = $Group" -Type 'INFO'

        # Get storage resource details
        switch($StorageSolution)
        {
            'AzureNetAppFiles' {
                $Credential = $DomainCredential
                $SmbServerName = (Get-ADComputer -Filter "Name -like 'anf-$SmbServerLocation*'" -Credential $DomainCredential).Name
                $FileServer = '\\' + $SmbServerName + '.' + $Domain.DNSRoot
            }
            'AzureFiles' {
                $StorageAccountName = $StorageAccountPrefix + ($i + $StorageIndex).ToString().PadLeft(2,'0')
                $FileServer = '\\' + $StorageAccountName + $FilesSuffix

                # Connects to Azure using a User Assigned Managed Identity
                If ($Environment -eq 'USNat') {
                    Add-AzEnvironment -AutoDiscover -Uri 'https://management.azure.eaglex.ic.gov/metadata/endpoints?api-version=2022-06' | Out-Null
                }
                Connect-AzAccount -Identity -AccountId $ClientId -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId | Out-Null
                Write-Log -Message "Authenticated to Azure" -Type 'INFO'

                # Get the storage account key
                $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName)[0].Value
                Write-Log -Message "The GET operation for the Storage Account key on $StorageAccountName succeeded" -Type 'INFO'

                # Create credential for accessing the storage account
                $StorageUsername = 'Azure\' + $StorageAccountName
                $StoragePassword = ConvertTo-SecureString -String "$($StorageKey)" -AsPlainText -Force
                [pscredential]$StorageKeyCredential = New-Object System.Management.Automation.PSCredential ($StorageUsername, $StoragePassword)
                $Credential = $StorageKeyCredential

                if($ActiveDirectorySolution -eq 'ActiveDirectoryDomainServices')
                {
                    # Get / create kerberos key for Azure Storage Account
                    $KerberosKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -ListKerbKey | Where-Object {$_.Keyname -contains 'kerb1'}).Value
                    if(!$KerberosKey)
                    {
                        New-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -KeyName kerb1 | Out-Null
                        $Key = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -ListKerbKey | Where-Object {$_.Keyname -contains 'kerb1'}).Value
                        Write-Log -Message "Kerberos Key creation on Storage Account, $StorageAccountName, succeeded." -Type 'INFO'
                    } 
                    else 
                    {
                        $Key = $KerberosKey
                        Write-Log -Message "Acquired Kerberos Key from Storage Account, $StorageAccountName." -Type 'INFO'
                    }

                    # Creates a password for the Azure Storage Account in AD using the Kerberos key
                    $ComputerPassword = ConvertTo-SecureString -String $Key.Replace("'","") -AsPlainText -Force
                    Write-Log -Message "Secure string conversion succeeded" -Type 'INFO'

                    # Create the SPN value for the Azure Storage Account; attribute for computer object in AD 
                    $SPN = 'cifs/' + $StorageAccountName + $FilesSuffix

                    # Create the Description value for the Azure Storage Account; attribute for computer object in AD 
                    $Description = "Computer account object for Azure storage account $($StorageAccountName)."

                    # Create the AD computer object for the Azure Storage Account
                    $Computer = Get-ADComputer -Credential $DomainCredential -Filter {Name -eq $StorageAccountName}
                    if($Computer)
                    {
                        Remove-ADComputer -Credential $DomainCredential -Identity $StorageAccountName -Confirm:$false
                    }
                    $ComputerObject = New-ADComputer -Credential $DomainCredential -Name $StorageAccountName -Path $OuPath -ServicePrincipalNames $SPN -AccountPassword $ComputerPassword -Description $Description -PassThru
                    Write-Log -Message "Computer object creation succeeded" -Type 'INFO'

                    # Update the Azure Storage Account with the domain join 'INFO'
                    $SamAccountName = switch($KerberosEncryptionType)
                    {
                        'AES256' {$StorageAccountName}
                        'RC4' {$ComputerObject.SamAccountName}
                    }

                    Set-AzStorageAccount `
                        -ResourceGroupName $StorageAccountResourceGroupName `
                        -Name $StorageAccountName `
                        -EnableActiveDirectoryDomainServicesForFile $true `
                        -ActiveDirectoryDomainName $Domain.DNSRoot `
                        -ActiveDirectoryNetBiosDomainName $Domain.NetBIOSName `
                        -ActiveDirectoryForestName $Domain.Forest `
                        -ActiveDirectoryDomainGuid $Domain.ObjectGUID `
                        -ActiveDirectoryDomainsid $Domain.DomainSID `
                        -ActiveDirectoryAzureStorageSid $ComputerObject.SID.Value `
                        -ActiveDirectorySamAccountName $SamAccountName `
                        -ActiveDirectoryAccountType 'Computer' | Out-Null
                    Write-Log -Message "Storage Account update with domain join info succeeded" -Type 'INFO'
                
                    # Enable AES256 encryption if selected
                    if($KerberosEncryptionType -eq 'AES256')
                    {
                        # Set the Kerberos encryption on the computer object
                        $DistinguishedName = 'CN=' + $StorageAccountName + ',' + $OuPath
                        Set-ADComputer -Credential $DomainCredential -Identity $DistinguishedName -KerberosEncryptionType 'AES256' | Out-Null
                        Write-Log -Message "Setting Kerberos AES256 Encryption on the computer object succeeded" -Type 'INFO'
                        
                        # Reset the Kerberos key on the Storage Account
                        New-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -KeyName kerb1 | Out-Null
                        $Key = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -ListKerbKey | Where-Object {$_.Keyname -contains 'kerb1'}).Value
                        Write-Log -Message "Resetting the Kerberos key on the Storage Account succeeded" -Type 'INFO'
                    
                        # Update the password on the computer object with the new Kerberos key on the Storage Account
                        $NewPassword = ConvertTo-SecureString -String $Key -AsPlainText -Force
                        Set-ADAccountPassword -Credential $DomainCredential -Identity $DistinguishedName -Reset -NewPassword $NewPassword | Out-Null
                        Write-Log -Message "Setting the new Kerberos key on the Computer Object succeeded" -Type 'INFO'
                    }
                }
                Disconnect-AzAccount | Out-Null
                Write-Log -Message "Disconnection to Azure succeeded" -Type 'INFO'
            }
        }
        
        foreach($Share in $Shares)
        {
            # Mount file share
            $FileShare = $FileServer + '\' + $Share
            New-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Root $FileShare -Credential $Credential | Out-Null
            Write-Log -Message "Mounting the Azure file share, $FileShare, succeeded" -Type 'INFO'

            # Set recommended NTFS permissions on the file share
            $ACL = Get-Acl -Path 'Z:'
            $CreatorOwner = New-Object System.Security.Principal.Ntaccount ("Creator Owner")
            $ACL.PurgeAccessRules($CreatorOwner)
            $AuthenticatedUsers = New-Object System.Security.Principal.Ntaccount ("Authenticated Users")
            $ACL.PurgeAccessRules($AuthenticatedUsers)
            $Users = New-Object System.Security.Principal.Ntaccount ("Users")
            $ACL.PurgeAccessRules($Users)
            $DomainUsers = New-Object System.Security.AccessControl.FileSystemAccessRule("$Group","Modify","None","None","Allow")
            $ACL.SetAccessRule($DomainUsers)
            $CreatorOwner = New-Object System.Security.AccessControl.FileSystemAccessRule("Creator Owner","Modify","ContainerInherit,ObjectInherit","InheritOnly","Allow")
            $ACL.AddAccessRule($CreatorOwner)
            $ACL | Set-Acl -Path 'Z:' | Out-Null
            Write-Log -Message "Setting the NTFS permissions on the Azure file share succeeded" -Type 'INFO'

            # Unmount file share
            Remove-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Force | Out-Null
            Start-Sleep -Seconds 5 | Out-Null
            Write-Log -Message "Unmounting the Azure file share, $FileShare, succeeded" -Type 'INFO'
        }
    }
    $Output = [pscustomobject][ordered]@{
        shares = $Shares
    }
    $JsonOutput = $Output | ConvertTo-Json
    return $JsonOutput
}
catch {
    Write-Log -Message $_ -Type 'ERROR'
    $ErrorData = $_ | Select-Object *
    $ErrorData | Out-File -FilePath 'C:\cse.txt' -Append
    throw
}