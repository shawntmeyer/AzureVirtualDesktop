targetScope = 'subscription'

param timeStamp string = utcNow()

module policyDefinition_vmSystemAssignedIdentity 'virtualMachine-SystemAssignedIdentity.policyDefinition.bicep' = {
  name: 'policyDefinition-SystemAssignedIdentity-${timeStamp}'
}

resource initiativeDefinition 'Microsoft.Authorization/policySetDefinitions@2024-05-01' = {
  name: 'virtualMachineMonitoring'
  properties: {
    description: 'This initiative configures Windows Virtual Machines to enable Monitoring with a single DCR and DCE.'
    displayName: 'Configure Virtual Machine Monitoring'
    metadata: {
      category: 'Monitoring'
      version: '1.0.0'
    }
    parameters: {
      dcrResourceId: {
        type: 'string'
        metadata: {
          displayName: 'Data Collection Rule'
          description: 'The Resource ID of the Data Collection Rule'
          strongType: 'Microsoft.Insights/dataCollectionRules'
          portalReview: true
        }
      }      
      dceResourceId: {
        type: 'string'
        metadata: {
          displayName: 'Data Collection Endpoint'
          description: 'The Resource Id of the Data Collection Endpoint.'
          strongType: 'Microsoft.Insights/dataCollectionEndpoints'
          portalReview: true
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: policyDefinition_vmSystemAssignedIdentity.outputs.resourceId
        policyDefinitionReferenceId: 'SystemAssignedManagedIdentity'
      }
      {
        policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'ca817e41-e85a-4783-bc7f-dc532d36235e')
        policyDefinitionReferenceId: 'DeployAzureMonitorAgent'
        parameters: {
          scopeToSupportedImages: {
            value: false
          }
        }
      }
      {
        policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', '244efd75-0d92-453c-b9a3-7d73ca36ed52')
        policyDefinitionReferenceId: 'DataCollectionRule'
        parameters: {
          dcrResourceId: {
            value: '[parameters(\'dcrResourceId\')]'
          }
          resourceType: {
            value: 'Microsoft.Insights/dataCollectionRules'
          }
          scopeToSupportedImages: {
            value: false
          }
        }
      }      
      {
        policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', '244efd75-0d92-453c-b9a3-7d73ca36ed52')
        policyDefinitionReferenceId: 'DataCollectionEndpoint'
        parameters: {
          dcrResourceId: {
            value: '[parameters(\'dceResourceId\')]'
          }
          resourceType: {
            value: 'Microsoft.Insights/dataCollectionEndpoints'
          }
          scopeToSupportedImages: {
            value: false
          }
        }
      }
    ]
  }
}

