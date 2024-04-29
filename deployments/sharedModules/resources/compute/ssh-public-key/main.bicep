metadata name = 'Public SSH Keys'
metadata description = '''This module deploys a Public SSH Key.

> Note: The resource does not auto-generate the key for you.'''
metadata owner = 'Azure/module-maintainers'

@description('Required. The name of the SSH public Key that is being created.')
param name string

@description('Optional. Resource location.')
param location string = resourceGroup().location

@description('Optional. SSH public key used to authenticate to a virtual machine through SSH. If this property is not initially provided when the resource is created, the publicKey property will be populated when generateKeyPair is called. If the public key is provided upon resource creation, the provided public key needs to be at least 2048-bit and in ssh-rsa format.')
param publicKey string = ''

@description('Optional. Tags of the availability set resource.')
param tags object = {}

resource sshPublicKey 'Microsoft.Compute/sshPublicKeys@2022-08-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    publicKey: !empty(publicKey) ? publicKey : null
  }
}

@description('The name of the Resource Group the Public SSH Key was created in.')
output resourceGroupName string = resourceGroup().name

@description('The resource ID of the Public SSH Key.')
output resourceId string = sshPublicKey.id

@description('The name of the Public SSH Key.')
output name string = sshPublicKey.name

@description('The location the resource was deployed into.')
output location string = sshPublicKey.location
