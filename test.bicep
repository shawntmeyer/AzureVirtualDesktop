param ArtifactsLocation string = 'https://saimageassetsuse.blob.core.windows.net/artifacts/'
param ArtifactsStorageAccountResourceId string = '/subscriptions/6dc4ed51-16b9-4494-a406-4fb7a8330d95/resourceGroups/rg-image-management-use/providers/Microsoft.Storage/storageAccounts/saimageassetsuse'
param ConvertedEpoch int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P0DT1H'))

var SignedExpiry = dateTimeFromEpoch(ConvertedEpoch)

var accountSasProperties = {
    signedServices: 'b'
    signedPermission: 'r'
    signedExpiry: SignedExpiry
    signedResourceTypes: 'co'
}

var SasToken = !empty(ArtifactsStorageAccountResourceId) ? storageAccount.listAccountSas('2023-01-01',accountSasProperties).accountSasToken : ''

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if(ArtifactsStorageAccountResourceId != '') {
  name: last(split(ArtifactsStorageAccountResourceId, '/'))
  scope: resourceGroup(split(ArtifactsStorageAccountResourceId, '/')[2], split(ArtifactsStorageAccountResourceId, '/')[4])
}

output SasToken string = SasToken
