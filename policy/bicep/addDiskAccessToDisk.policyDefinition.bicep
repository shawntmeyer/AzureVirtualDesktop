targetScope = 'subscription'

//this is a built-in policy definition from https://github.com/Azure/azure-policy/blob/master/built-in-policies/policyDefinitions/Compute/AddDiskAccessToDisk_Modify.json

var policyJson = loadJsonContent('../definitions/AddDiskAccessToDisk_Modify.policyDefinition.json')

resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: policyJson.name
  properties: {
    description: policyJson.properties.description
    displayName: policyJson.properties.displayName
    mode: policyJson.properties.mode
    parameters: policyJson.properties.parameters
    policyRule: policyJson.properties.policyRule
  }
}
