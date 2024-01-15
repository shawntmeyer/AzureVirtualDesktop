[Cmdletbinding()]
Param(
    [parameter(Mandatory)]
    [int]
    $CpuCountMax,
    
    [parameter(Mandatory)]
    [int]
    $CpuCountMin,

    [parameter()]
    [string]
    $DomainName = '',

    [parameter(Mandatory)]
    [string]
    $Environment,

    [parameter()]
    [string]
    $KerberosEncryption,

    [parameter(Mandatory)]
    [string]
    $Location,

    [parameter(Mandatory)]
    [int]
    $SessionHostCount,

    [parameter(Mandatory)]
    [string]
    $StorageSolution,

    [parameter(Mandatory)]
    [string]
    $SubscriptionId,

    [parameter(Mandatory)]
    [string]
    $TenantId,

    [parameter(Mandatory)]
    [string]
    $UserAssignedIdentityClientId,

    [parameter(Mandatory)]
    [string]
    $VirtualMachineSize,

    [parameter(Mandatory)]
    [string]
    $VirtualNetworkName,

    [parameter(Mandatory)]
    [string]
    $VirtualNetworkResourceGroupName,

    [parameter(Mandatory)]
    [string]
    $WorkspaceName,

    [parameter(Mandatory)]
    [string]
    $WorkspaceResourceGroupName
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
        New-Item -Path 'C:\' -Name 'cse.txt' | Out-Null
    }
    $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
    $Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
    $Entry | Out-File -FilePath $Path -Append
}

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

try 
{
    Connect-AzAccount -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId -Identity -AccountId $UserAssignedIdentityClientId | Out-Null
    $Sku = Get-AzComputeResourceSku -Location $Location | Where-Object {$_.ResourceType -eq "virtualMachines" -and $_.Name -eq $VirtualMachineSize}
    
    ##############################################################
    # Accelerated Networking Validation
    ##############################################################
    $AcceleratedNetworking = ($Sku.capabilities | Where-Object {$_.name -eq "AcceleratedNetworkingEnabled"}).value
    Write-Log -Message "Accelerated Networking Validation Succeeded" -Type 'INFO'

    ##############################################################
    # Availability Zone Validation
    ##############################################################
    $AvailabilityZones = $Sku.locationInfo.zones | Sort-Object
    Write-Log -Message "Accelerated Networking Validation Succeeded" -Type 'INFO'

    ##############################################################
    # Azure NetApp Files Validation
    ##############################################################
    If ($StorageSolution -eq 'AzureNetAppFiles') {
        $Vnet = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VirtualNetworkResourceGroupName
        If ($null -ne $Vnet.DhcpOptions.DnsServers) {
            $DnsServers = "$($Vnet.DhcpOptions.DnsServers[0]),$($Vnet.DhcpOptions.DnsServers[1])"
        }
        $SubnetId = ($Vnet.Subnets | Where-Object {$_.Delegations[0].ServiceName -eq "Microsoft.NetApp/volumes"}).Id
        if($null -eq $SubnetId -or $SubnetId -eq "")
        {
            Write-Error -Exception "INVALID AZURE NETAPP FILES CONFIGURATION: A dedicated subnet must be delegated to the ANF resource provider."
        }
        $DeployAnfAd = "true"
        $Accounts = Get-AzResource -ResourceType "Microsoft.NetApp/netAppAccounts" | Where-Object {$_.Location -eq $Location}
        foreach($Account in $Accounts)
        {
            $AD = Get-AzNetAppFilesActiveDirectory -ResourceGroupName $Account.ResourceGroupName -AccountName $Account.Name
            if($AD.ActiveDirectoryId)
            {
                $DeployAnfAd = "false"
            }
        }
        Write-Log -Message "Azure NetApp Files Validation Succeeded" -Type 'INFO'
    }

    ##############################################################
    # Disk SKU Validation
    ##############################################################
    if(($Sku.capabilities | Where-Object {$_.name -eq "PremiumIO"}).value -eq $false)
    {
        Write-Error -Exception "INVALID DISK SKU: The selected VM Size does not support the Premium SKU for managed disks."
    }
    Write-Log -Message "Disk SKU Validation Succeeded" -Type 'INFO'

    ##############################################################
    # Hyper-V Generation Validation
    ##############################################################
    if(($Sku.capabilities | Where-Object {$_.name -eq "HyperVGenerations"}).value -notlike "*2")
    {
        Write-Error -Exception "INVALID HYPER-V GENERATION: The selected VM size does not support the selected Image Sku."
    }
    Write-Log -Message "Hyper-V Generation Validation Succeeded" -Type 'INFO'

    ##############################################################
    # Kerberos Encryption Validation
    ##############################################################
    If ($ActiveDirectorySolution -eq 'AzureActiveDirectoryDomainServices') {
        $KerberosRc4Encryption = (Get-AzResource -Name $DomainName -ExpandProperties).Properties.domainSecuritySettings.kerberosRc4Encryption
        if($KerberosRc4Encryption -eq "Enabled" -and $KerberosEncryption -eq "AES256")
        {
            Write-Error -Exception "INVALID KERBEROS ENCRYPTION: The Kerberos Encryption on Azure AD DS does not match your Kerberos Encryption selection."
        }
        Write-Log -Message "Kerberos Encryption Validation Succeeded" -Type 'INFO'
    }

    ##############################################################
    # Trusted Launch Validation
    ##############################################################
    if($null -eq ($Sku.capabilities | Where-Object {$_.name -eq "TrustedLaunchDisabled"}).value)
    {
        $TrustedLaunch = "true"
    }
    else
    {
        $TrustedLaunch = "false"
    }
    Write-Log -Message "Trusted Launch Validation Succeeded" -Type 'INFO'

    ##############################################################
    # vCPU Count Validation
    ##############################################################
    # Recommended minimum vCPU is 4 for multisession hosts and 2 for single session hosts.
    # Recommended maximum vCPU is 32 for multisession hosts and 128 for single session hosts.
    # https://learn.microsoft.com/windows-server/remote/remote-desktop-services/virtual-machine-recs
    $vCPUs = [int]($Sku.capabilities | Where-Object {$_.name -eq "vCPUs"}).value
    if($vCPUs -lt $CpuCountMin -or $vCPUs -gt $CpuCountMax)
    {
        Write-Error -Exception "INVALID VCPU COUNT: The selected VM Size does not contain the appropriate amount of vCPUs for Azure Virtual Desktop. https://learn.microsoft.com/windows-server/remote/remote-desktop-services/virtual-machine-recs"
    }
    Write-Log -Message "vCPU Count Validation Succeeded" -Type 'INFO'

    ##############################################################
    # vCPU Quota Validation
    ##############################################################
    $RequestedCores = $vCPUs * $SessionHostCount
    $Family = (Get-AzComputeResourceSku -Location $Location | Where-Object {$_.Name -eq $VirtualMachineSize}).Family
    $CpuData = Get-AzVMUsage -Location $Location | Where-Object {$_.Name.Value -eq $Family}
    $AvailableCores = $CpuData.Limit - $CpuData.CurrentValue; $RequestedCores = $vCPUs * $SessionHostCount
    if($RequestedCores -gt $AvailableCores)
    {
        Write-Error -Exception "INSUFFICIENT CORE QUOTA: The selected VM size, $VirtualMachineSize, does not have adequate core quota in the selected location."
    }
    Write-Log -Message "vCPU Quota Validation Succeeded" -Type 'INFO'

    ##############################################################
    # vCPU Quota Validation
    ##############################################################
    $Workspace = Get-AzResource -ResourceGroupName $WorkspaceResourceGroupName -ResourceName $WorkspaceName
    Write-Log -Message "Existing Workspace Validation Succeeded" -Type 'INFO'


    Disconnect-AzAccount | Out-Null

    $Output = [pscustomobject][ordered]@{
        acceleratedNetworking = $AcceleratedNetworking
        anfDnsServers = if($StorageSolution -eq "AzureNetAppFiles"){$DnsServers}else{"NotApplicable"}
        anfSubnetId = if($StorageSolution -eq "AzureNetAppFiles"){$SubnetId}else{"NotApplicable"}
        anfActiveDirectory = if($StorageSolution -eq "AzureNetAppFiles"){$DeployAnfAd}else{"false"}
        availabilityZones = $AvailabilityZones
        existingWorkspace = if($Workspace){"true"}else{"false"}
        trustedLaunch = $TrustedLaunch
    }
    $JsonOutput = $Output | ConvertTo-Json
    return $JsonOutput
}
catch 
{
    Write-Log -Message $_ -Type 'ERROR'
    throw
}