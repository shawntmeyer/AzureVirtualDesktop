targetScope = 'subscription'

param policyDefinitionName string = 'virtualMachineDiskEncryptionSet-Modify'
param policyDefinitionDisplayName string = 'Configure virtual machines operationg system disk with disk encryption set'
param policyDefinitionDescription string = 'This policy will modify the disk encryption set of the operating system disk of virtual machines in order to enable customer-managed keys for encryption.'

var policyJson = loadJsonContent('../definitions/DiskEncryptionSet.policyDefinition.json')

resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: policyDefinitionName
  properties: {
    description: empty(policyDefinitionDescription) ? policyJson.description : policyDefinitionDescription
    displayName: empty(policyDefinitionDisplayName) ? policyJson.displayName : policyDefinitionDisplayName
    mode: policyJson.mode
    metadata: policyJson.metadata
    parameters: policyJson.parameters
    policyRule: policyJson.policyRule
  }
}

output policyDefinitionResourceId string = policyDefinition.id
