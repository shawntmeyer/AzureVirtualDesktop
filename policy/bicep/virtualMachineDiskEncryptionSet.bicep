targetScope = 'managementGroup'

param diskEncryptionSetResourceId string
param policyDefinitionNameDES string
param policyDefinitionDisplayNameDES string
param policyDefinitionDescriptionDES string = ''
param subscriptionId string = ''

module policyDefinition_DES '../../deployments/sharedModules/resources/authorization/policy-definition/main.bicep' = {
  name: 'dep-PolicyDefinition-AssignIdentity'
  params: {
    name: policyDefinitionNameDES
    mode: 'Indexed'
    displayName: policyDefinitionDisplayNameDES
    description: policyDefinitionDescriptionDES
    subscriptionId: subscriptionId
    parameters: {
      diskEncryptionSetResourceId: {
        type: 'String'
        defaultValue: ''
        metadata: {
          displayName: 'Disk Encryption Set Resource ID'
          description: 'The Resource ID of the Disk Encryption Set used to use customer managed keys for encrypting the Virtual Machine OS Disk.'
          strongType: 'Microsoft.Compute/diskEncryptionSets'
          portalReview: true
        }
      }
    }
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.Compute/virtualMachines'
      }
      then: {
        effect: 'modify'
        details: {
          operations: [
            {
              operation: 'addOrReplace'
              field: 'Microsoft.Compute/virtualMachines/storageProfile.osDisk.managedDisk.diskEncryptionSet.id'
              value: diskEncryptionSetResourceId
            }
          ]
          roleDefinitionIds: [
            '/providers/microsoft.authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
          ]
        }
      }
    }
  }
}
