targetScope = 'subscription'
param policyDefinitionName string = 'CustomScriptExtensionPolicy'
param artifactsUri string
param fileUris array
param scriptToRun string
param scriptArguments string
param userAssignedIdentityClientId string

var baseUri = last(artifactsUri) == '/' ? artifactsUri : '${artifactsUri}/'
var cseUris = [for uri in fileUris: !contains(uri, '/') ? '${baseUri}${uri}' : uri]
var baseCommand = 'powershell -ExecutionPolicy Unrestricted -Command .\\${scriptToRun}'
var commandToExecute = !empty(scriptArguments) ? '${baseCommand} ${scriptArguments}' : baseCommand

resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: policyDefinitionName
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    description: 'This policy deploys the Custom Script Extension on all Windows Virtual Machines.'
    metadata: {
      category: 'Custom Script Extension'
      version: '1.0.0'
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
          {
            field: 'Microsoft.Compute/virtualMachines/storageProfile.osDisk.osType'
            equals: 'Windows'
          }
        ]
      }
      then: {
        effect: 'deployIfNotExists'
        details: {
          name: 'AzurePolicyforWindows'
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          type: 'Microsoft.Compute/virtualMachines/extensions'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/publisher'
                equals: 'Microsoft.Compute'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/type'
                equals: 'CustomScriptExtension'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          deployment: {
            properties: {
              mode: 'Incremental'
              template: {
                
              }
            }
          }
        }
      }
    }
  }
}
