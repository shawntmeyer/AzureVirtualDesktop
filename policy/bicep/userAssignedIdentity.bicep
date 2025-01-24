targetScope = 'managementGroup'

param policyDefinitionNameUAI string
param policyDefinitionDisplayNameUAI string
param policyDefinitionDescriptionUAI string = ''
param subscriptionId string = ''

module policyDefinition_DES '../../deployments/sharedModules/resources/authorization/policy-definition/main.bicep' = {
  name: 'dep-PolicyDefinition-AssignIdentity'
  params: {
    name: policyDefinitionNameUAI
    mode: 'Indexed'
    displayName: policyDefinitionDisplayNameUAI
    description: policyDefinitionDescriptionUAI
    subscriptionId: subscriptionId
    parameters: loadJsonContent('../definitions/policy-AssignUser-AssignedIdentity.json', 'parameters')
    policyRule: loadJsonContent('../definitions/policy-AssignUser-AssignedIdentity.json', 'policyRule')
  }
}
