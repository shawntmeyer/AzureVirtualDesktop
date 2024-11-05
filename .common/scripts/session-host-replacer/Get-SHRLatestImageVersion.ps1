function Get-SHRLatestImageVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ResourceManagerUrl,

        [Parameter(Mandatory = $true)]
        [psobject] $RestHeader,

        [Parameter(Mandatory = $true)]
        [string] $SubscriptionId,

        # An Image reference object. Can be from Marketplace or Shared Image Gallery.
        [Parameter()]
        [hashtable] $ImageReference,

        [Parameter()]
        [string] $Location
    )

    # Marketplace image
    if ($ImageReference.publisher) {
        #TODO Do we need to change location here?
        if ($ImageReference.version -ne 'latest') {
            Write-OutputDetailed -Message "Image version is not set to latest. Returning version '$($ImageReference.version)'"
            $azImageVersion = $ImageReference.version
        }
        else {
            # Get the Images and select the latest version.           
            Write-OutputDetailed -Message "Getting latest version of image publisher: $($ImageReference.publisher), offer: $($ImageReference.offer), sku: $($ImageReference.sku) in region: $($Location)"
                      
            $Uri = $ResourceManagerUrl + "/subscriptions/$SubscriptionId/providers/Microsoft.Compute/locations/$Location/publishers/$($ImageReference.publisher)/artifacttypes/vmimage/offers/$($ImageReference.offer)/skus/$($ImageReference.sku)/versions?api-version=2024-07-01"
            
            $Versions = Invoke-RestMethod -Uri $Uri -Headers $RestHeader -Method Get

            $azImageVersion = ($Versions | Sort-Object -Property {[version] $_.Name} -Descending | Select-Object -First 1).Name
            Write-OutputDetailed -Message "Latest version of image is $azImageVersion"

            if ($azImageVersion -match "\d+\.\d+\.(?<Year>\d{2})(?<Month>\d{2})(?<Day>\d{2})") {
                $azImageDate = Get-Date -Date ("20{0}-{1}-{2}" -f $Matches.Year, $Matches.Month, $Matches.Day)
                Write-OutputDetailed -Message "Image date is $azImageDate"
            }
            else {
                throw "Image version does not match expected format. Could not extract image date."
            }
        }
    }
    elseif ($ImageReference.Id) {
        # Shared Image Gallery
        Write-PSFMessage -Level Host -Message 'Image is from Shared Image Gallery: {0}' -StringValues $ImageReference.Id
        $imageDefinitionResourceIdPattern = '^\/subscriptions\/(?<subscription>[a-z0-9\-]+)\/resourceGroups\/(?<resourceGroup>[^\/]+)\/providers\/Microsoft\.Compute\/galleries\/(?<gallery>[^\/]+)\/images\/(?<image>[^\/]+)$'
        $imageVersionResourceIdPattern = '^\/subscriptions\/(?<subscription>[a-z0-9\-]+)\/resourceGroups\/(?<resourceGroup>[^\/]+)\/providers\/Microsoft\.Compute\/galleries\/(?<gallery>[^\/]+)\/images\/(?<image>[^\/]+)\/versions\/(?<version>[^\/]+)$'
        if ($ImageReference.Id -match $imageDefinitionResourceIdPattern) {
            Write-PSFMessage -Level Host -Message 'Image reference is an Image Definition resource.'
            $imageSubscriptionId = $Matches.subscription
            $imageResourceGroup = $Matches.resourceGroup
            $imageGalleryName = $Matches.gallery
            $imageDefinitionName = $Matches.image

            # Get the latest version of the image
            $latestImageVersion = Get-AzGalleryImageVersion -ResourceGroupName $imageResourceGroup -GalleryName $imageGalleryName -GalleryImageName $imageDefinitionName |
                                         Where-Object { $_.PublishingProfile.ExcludeFromLatest -eq $false } |
                                         Sort-Object -Property {$_.PublishingProfile.PublishedDate} -Descending |
                                         Select-Object -First 1
            if (-not $latestImageVersion) {
                throw "No available image versions found."
            }
            Write-PSFMessage -Level Host -Message "Selected image version with resource Id {0}" -StringValues $latestImageVersion.Id
            $azImageVersion = $latestImageVersion.Name
            $azImageDate = $latestImageVersion.PublishingProfile.PublishedDate

            Write-PSFMessage -Level Host -Message "Image version is {0} and date is {1}" -StringValues $azImageVersion, $azImageDate.ToString('o')

            # Switch back to original subscription
            if ($imageSubscriptionId -ne $currentSubscriptionId) {
                Write-PSFMessage -Level Host -Message "Switching back to subscription {0}" -StringValues $currentSubscriptionId
                Set-AzContext -SubscriptionId $currentSubscriptionId
            }
        }
        elseif ($ImageReference.Id -match $imageVersionResourceIdPattern ) {
            Write-PSFMessage -Level Host -Message 'Image reference is an Image Version resource.'
            $imageVersion = Get-AzGalleryImageVersion -ResourceId $ImageReference.Id
            $azImageVersion = $imageVersion.Name
            $azImageDate = $imageVersion.PublishingProfile.PublishedDate
            Write-PSFMessage -Level Host -Message "Image version is {0} and date is {1}" -StringValues $azImageVersion, $azImageDate.ToString('o')
        }
        else {
            throw "Image reference Id does not match expected format for an Image Definition resource."
        }
    }
    else {
        throw "Image reference does not contain a publisher or Id property. ImageReference, publisher, and Id are case sensitive!!"
    }
    #return output
    [PSCustomObject]@{
        Version = $azImageVersion
        Date    = $azImageDate
    }
}