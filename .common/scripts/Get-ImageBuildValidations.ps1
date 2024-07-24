param(
    [Parameter(ParameterSetName = 'ExistingID', Mandatory = $true)]
    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ResourceManagerUri,

    [Parameter(ParameterSetName = 'ExistingID', Mandatory = $true)]
    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$UserAssignedIdentityClientId,

    [Parameter(ParameterSetName = 'ExistingID', Mandatory = $true)]
    [string]$ImageDefinitionResourceId,

    [Parameter(ParameterSetName = 'ExistingID', Mandatory = $true)]
    [string]$SourceSku,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageGalleryResourceId,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageLocation,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageName,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageHyperVGeneration,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImagePublisher,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageOffer,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageSku,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageSecurityType,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageIsHibernateSupported,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageIsAcceleratedNetworkSupported,

    [Parameter(ParameterSetName = 'NewID', Mandatory = $true)]
    [string]$ImageIsHigherStoragePerformanceSupported
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

Try {
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

    If ($ImageDefinitionResourceId) {
        $ImageDefinition = Invoke-RestMethod `
            -Headers $AzureManagementHeader `
            -Method 'Get' `
            -Uri $($ResourceManagerUriFixed + $ImageDefinitionResourceId + '?api-version=2023-07-03')
        $HyperVGeneration = $ImageDefinition.properties.hyperVGeneration
        
        If ($SourceSku.EndsWith('g2') -or $sourceSku.StartsWith('win11')) {
            $sourceHyperVGen = 'V2'
        }
        Else {
            $sourceHyperVGen = 'V1'
        }

        If ($sourceHyperVGen -ne $HyperVGeneration) {
            Write-Error -Exception "INVALID IMAGE DEFINITION: Hyper-V Generation mismatch."
        }

        $OsState = $ImageDefinition.properties.osState
        If ($OsState -ne 'Generalized') {
            Write-Error -Exception "INVALID IMAGE DEFINITION: OsState is not 'Generalized'."
        }

        $Architecture = $ImageDefinition.properties.architecture
        If ($Architecture -ne 'X64') {
            Write-Error -Exception "INVALID IMAGE DEFINITION: Architecture is not 'x64'."
        }

        $DiskControllerTypes = ($ImageDefinition.properties.features | Where-Object { $_.Name -eq 'DiskControllerTypes' }).Value
        If (!$DiskControllerTypes) { $DiskControllerTypes = 'SCSI' }

        $IsAcceleratedNetworkSupported = ($ImageDefinition.properties.features | Where-Object { $_.Name -eq 'IsAcceleratedNetworkSupported' }).Value
        If (!$IsAcceleratedNetworkSupported) { $IsAcceleratedNetworkSupported = 'False' }

        $IsHibernateSupported = ($ImageDefinition.properties.features | Where-Object { $_.Name -eq 'IsHibernateSupported' }).Value
        If (!$IsHibernateSupported) { $IsHibernateSupported = 'False' }

        $SecurityType = ($ImageDefinition.Features | Where-Object { $_.Name -eq 'SecurityType' }).Value
        If (!$SecurityType) { $SecurityType = 'Standard' }    
    }
    Else {
        # New Image Definition Specified. Validate that we don't already have one with the same name and that we won't try to overwrite non-updateable properties.
        $ImageDefinitions = (Invoke-RestMethod `
            -Headers $AzureManagementHeader `
            -Method 'Get' `
            -Uri $($ResourceManagerUriFixed + $ImageGalleryResourceId + '/images?api-version=2023-07-03')).value
        ForEach ($ImageDefinition in $ImageDefinitions) {      
            If ($ImageDefinition.name -eq $ImageName) {
                $ImgDefProps = $ImageDefinition.properties
                If ($ImageDefinition.location-ne $ImageLocation) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: An Image Definition with the same name in the same gallery already exists in another region."
                }
                If ($ImgDefProps.architecture-ne 'X64') {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Architecture is not 'x64'."
                }
                If ($ImgDefProps.hyperVGeneration -ne $ImageHyperVGeneration) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Hyper-V Generation mismatch."
                }
                If ($ImgDefProps.osState -ne 'Generalized') {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: OsState is not 'Generalized'."
                }
                $ImgDefIdentifier = $ImgDefProps.identifier
                If (!($ImgDefIdentifier.publisher -eq $imagePublisher -and $ImgDefIdentifier.offer -eq $imageOffer -and $ImgDefIdentifier.sku -eq $imageSku)) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Existing Image definition found with different identifier information."
                }
                $ImgDefFeatures = $ImgDefProps.features
                $DiskControllerTypes = ($ImgDefFeatures | Where-Object { $_.Name -eq 'DiskControllerTypes' }).Value
                If (!$DiskControllerTypes -or $DiskControllerTypes -eq 'SCSI') {
                    $HigherPerformanceStorageSupported = 'False'
                }
                Else {
                    $HigherPerformanceStorageSupported = 'True'
                }
                If ($HigherPerformanceStorageSupported -ne $ImageIsHigherStoragePerformanceSupported) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Disk Controller Types support mismatch."
                }
                $IsAcceleratedNetworkSupported = ($ImgDefFeatures | Where-Object { $_.Name -eq 'IsAcceleratedNetworkSupported' }).Value
                If ($IsAcceleratedNetworkSupported -ne $ImageIsAcceleratedNetworkSupported) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Accelerated Network Support mismatch."
                }
                $IsHibernateSupported = ($ImgDefFeatures | Where-Object { $_.Name -eq 'IsHibernateSupported' }).Value
                If ($IsHibernateSupported -ne $ImageIsHibernateSupported) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: Hibernate Support mismatch."
                }
                $SecurityType = ($ImgDefFeatures | Where-Object { $_.Name -eq 'SecurityType' }).Value
                If (!$SecurityType) { $SecurityType = 'Standard' }
                If ($SecurityType -ne $ImageSecurityType) {
                    Write-Error -Exception "INVALID IMAGE DEFINITION: SecurityType mismatch."
                }
            }
        }
    }

    If ($ImageDefinitionResourceId) {

        $Output = [pscustomobject][ordered]@{
            HyperVGeneration              = $HyperVGeneration
            OsState                       = $OsState
            DiskControllerTypes           = $DiskControllerTypes
            IsAcceleratedNetworkSupported = $IsAcceleratedNetworkSupported
            IsHibernateSupported          = $IsHibernateSupported
            SecurityType                  = $SecurityType
        }
        
    }
    Else {
        $Output = [PSCustomObject][ordered]@{
            Validated = $True
        }
    }

    $JsonOutput = $Output | ConvertTo-Json
    return $JsonOutput
}
catch {
    throw
}