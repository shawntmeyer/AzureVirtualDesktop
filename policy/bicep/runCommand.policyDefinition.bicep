targetScope = 'subscription'

param policyDefinitionName string = 'runCommand-Modify'
param policyDefinitionDisplayName string = 'Run Command on Virtual Machines'
param policyDefinitionDescription string = 'This policy will enable the Run Command feature on virtual machines.'

var policyJson = loadJsonContent('../definitions/RunCommand.policyDefinition.json')

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
