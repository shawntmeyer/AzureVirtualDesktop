[Cmdletbinding()]
Param(
    [Parameter(ParameterSetName='ExistingID', Mandatory=$true)]
    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$Environment,

    [Parameter(ParameterSetName='ExistingID', Mandatory=$true)]
    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(ParameterSetName='ExistingID', Mandatory=$true)]
    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$TenantId,

    [Parameter(ParameterSetName='ExistingID', Mandatory=$true)]
    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$UserAssignedIdentityClientId,

    [Parameter(ParameterSetName='ExistingID', Mandatory=$true)]
    [string]$ImageDefinitionResourceId,

    [Parameter(ParameterSetName='ExistingID', Mandatory=$true)]
    [string]$SourceSku,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageGalleryResourceId,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageLocation,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageName,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageHyperVGeneration,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImagePublisher,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageOffer,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageSku,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageSecurityType,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageIsHibernateSupported,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageIsAcceleratedNetworkSupported,

    [Parameter(ParameterSetName='NewID', Mandatory=$true)]
    [string]$ImageIsHigherStoragePerformanceSupported
)

function Write-Log {
    param(
        [parameter(Mandatory)]
        [string]$Message,
        
        [parameter(Mandatory)]
        [string]$Type
    )
    $Path = "$env:Temp\cse.txt"
    if(!(Test-Path -Path $Path))
    {
        New-Item -Path $Path -ItemType file | Out-Null
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
    
    If ($ImageDefinitionResourceId) {
        # existing image specified. Fix SecurityType if needed with output and validate other properties for build.
        $ImageDefinition = Get-AzGalleryImageDefinition -ResourceId $ImageDefinitionResourceId

        $HyperVGeneration = $ImageDefinition.HyperVGeneration
        Write-Log -Message "HyperVGeneration is '$HyperVGeneration'" -Type 'INFO'

        If ($SourceSku.EndsWith('g2') -or $sourceSku.StartsWith('win11')) {
            $sourceHyperVGen = 'V2'
        } Else {
            $sourceHyperVGen = 'V1'
        }

        If ($sourceHyperVGen -ne $HyperVGeneration) {
            Write-Error -Exception "INVALID IMAGE DEFINITION: Hyper-V Generation mismatch."
        }

        $OsState = $ImageDefinition.OsState
        Write-Log -Message "OsState is '$OsState'" -Type 'INFO'

        If ($OsState -ne 'Generalized') {
            Write-Error -Exception "INVALID IMAGE DEFINITION: OsState is not 'Generalized'."
        }

        $Architecture = $ImageDefinition.Architecture
        Write-Log -Message "Architecture is '$Architecture'" -Type 'INFO'

        If ($Architecture -ne 'X64') {
            Write-Error -Exception "INVALID IMAGE DEFINITION: Architecture is not 'x64'."
        }

        $DiskControllerTypes = ($ImageDefinition.Features | Where-Object {$_.Name -eq 'DiskControllerTypes'}).Value
        If (!$DiskControllerTypes) {$DiskControllerTypes = 'SCSI'}
        Write-Log -Message "DiskControllerTypes set to '$DiskControllerTypes'" -Type 'INFO'

        $IsAcceleratedNetworkSupported = ($ImageDefinition.Features | Where-Object {$_.Name -eq 'IsAcceleratedNetworkSupported'}).Value
        If (!$IsAcceleratedNetworkSupported) {$IsAcceleratedNetworkSupported = 'False'}
        Write-Log -Message "IsHibernateSupported set to '$IsHibernateSupported'" -Type 'INFO'

        $IsHibernateSupported = ($ImageDefinition.Features | Where-Object {$_.Name -eq 'IsHibernateSupported'}).Value
        If (!$IsHibernateSupported) {$IsHibernateSupported = 'False'}
        Write-Log -Message "IsHibernateSupported set to '$IsHibernateSupported'" -Type 'INFO'

        $SecurityType = ($ImageDefinition.Features | Where-Object {$_.Name -eq 'SecurityType'}).Value
        If (!$SecurityType) {$SecurityType = 'Standard'}    
        Write-Log -Message "SecurityType set to '$SecurityType'" -Type 'INFO'

    } Else {
        # New Image Definition Specified. Validate that we don't already have one with the same name and that we won't try to overwrite non-updateable properties.
        [array]$GalleryId = $ImageGalleryResourceId -Split '/'
        $GalleryName = $GalleryId[8]
        $ResourceGroupName = $GalleryId[4]
        $ImageDefinitions = Get-AzGalleryImageDefinition -GalleryName $GalleryName -ResourceGroupName $ResourceGroupName
        ForEach ($ImageDefinition in $ImageDefinitions) {
            $Name = $ImageDefinition.Name
            If ($Name -eq $ImageName) {
                
                Write-Log -Message "The specified image definition name '$ImageName' already exists in Azure Compute Gallery: '$GalleryName'. Checking properties to prevent conflict." -Type 'INFO'
                $Architecture = $ImageDefinition.Architecture
                If ($Architecture -ne 'X64') {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Architecture is not 'x64'."
                }
                $HyperVGeneration = $ImageDefinition.HyperVGeneration
                If ($HyperVGeneration -ne $ImageHyperVGeneration) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Hyper-V Generation mismatch."
                }
                $Location = $ImageDefinition.Location
                If ($Location -ne $ImageLocation) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: An Image Definition with the same name in the same gallery already exists in another region."
                }
                $OsState = $ImageDefinition.OsState
                If ($OsState -ne 'Generalized') {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: OsState is not 'Generalized'."
                }
                $Publisher = $ImageDefinition.Identifier.Publisher
                $Offer = $ImageDefinition.Identifier.Offer
                $Sku = $ImageDefinition.Identifier.Sku
                If ($Publisher -eq $imagePublisher -and $Offer -eq $imageOffer -and $Sku -eq $imageSku) {
                    Write-Log -Message "Identifier information matches." -Type 'INFO'
                } Else {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Existing Image definition found with different identifier information."
                }

                $DiskControllerTypes = ($ImageDefinition.Features | Where-Object {$_.Name -eq 'DiskControllerTypes'}).Value
                If (!$DiskControllerTypes -or $DiskControllerTypes -eq 'SCSI') {
                    $HigherPerformanceStorageSupported = 'False'
                } Else {
                    $HigherPerformanceStorageSupported = 'True'
                }
                If ($HigherPerformanceStorageSupported -ne $ImageIsHigherStoragePerformanceSupported) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Disk Controller Types support mismatch."
                }
                $IsAcceleratedNetworkSupported = ($ImageDefinition.Features | Where-Object {$_.Name -eq 'IsAcceleratedNetworkSupported'}).Value
                If ($IsAcceleratedNetworkSupported -ne $ImageIsAcceleratedNetworkSupported) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Accelerated Network Support mismatch."
                }
                $IsHibernateSupported = ($ImageDefinition.Features | Where-Object {$_.Name -eq 'IsHibernateSupported'}).Value
                If ($IsHibernateSupported -ne $ImageIsHibernateSupported) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Hibernate Support mismatch."
                }
                $SecurityType = ($ImageDefinition.Features | Where-Object {$_.Name -eq 'SecurityType'}).Value
                If (!$SecurityType) {$SecurityType = 'Standard'}
                If ($SecurityType -ne $ImageSecurityType) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: SecurityType mismatch."
                }
            } 

        }
    }
    
    Write-Log -Message "Done Gathering" -Type 'INFO'

    Disconnect-AzAccount | Out-Null

    If ($ImageDefinitionResourceId) {

        $Output = [pscustomobject][ordered]@{
            HyperVGeneration = $HyperVGeneration
            OsState = $OsState
            DiskControllerTypes = $DiskControllerTypes
            IsAcceleratedNetworkSupported = $IsAcceleratedNetworkSupported
            IsHibernateSupported = $IsHibernateSupported
            SecurityType = $SecurityType
        }
        
    } Else {
        $Output = [PSCustomObject][ordered]@{
            Validated = $True
        }
    }

    $JsonOutput = $Output | ConvertTo-Json
    return $JsonOutput
}
catch 
{
    Write-Log -Message $_ -Type 'ERROR'
    throw
}