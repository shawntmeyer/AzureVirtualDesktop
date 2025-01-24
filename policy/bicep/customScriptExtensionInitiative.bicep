targetScope = 'managementGroup'

param policyDefinitionNameAUAI string
param policyDefinitionDisplayNameAUAI string
param policyDefinitionDescriptionAUAI string = ''
param policyDefinitionNameCSE string
param policyDefinitionDisplayNameCSE string
param policyDefinitionDescriptionCSE string = ''
param subscriptionId string = ''
param policySetDefinitionName string
param policySetDefinitionDisplayName string
param policySetDefinitionDescription string = ''

module policyDefinition_AUAI '../../deployments/sharedModules/resources/authorization/policy-definition/main.bicep' = {
  name: 'dep-PolicyDefinition-AssignIdentity'
  params: {
    name: policyDefinitionNameAUAI
    mode: 'Indexed'
    displayName: policyDefinitionDisplayNameAUAI
    description: policyDefinitionDescriptionAUAI
    subscriptionId: subscriptionId
    parameters: {
      userAssignedIdentityResourceId: {
        type: 'String'
        defaultValue: ''
        metadata: {
          displayName: 'User Assigned Identity Resource ID'
          description: 'The Resource ID of the user assigned identity that has access to the artifactsUri.'
          strongType: 'Microsoft.ManagedIdentity/userAssignedIdentities'
          portalReview: true
        }
      }
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
        effect: 'DeployIfNotExists'
        details: {
          type: 'Microsoft.Compute/virtualMachines'
          name: '[field(\'name\')]'
          existenceCondition: {
            allOf: [
              {
                field: 'identity.type'
                contains: 'UserAssigned'
              }
              {
                field: 'identity.userAssignedIdentities'
                containsKey: '[parameters(\'userAssignedIdentityResourceId\')]'
              }
            ]
          }
          roleDefinitionIds: [
            '/providers/microsoft.authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
          ]
        }
        deployment: {
          properties: {
            mode: 'Incremental'
            parameters: {
              location: '[field(\'location\')]'
              userAssignedIdentityResourceId: {
                value: '[parameters(\'userAssignedIdentityResourceId\')]'
              }
              vmname: '[field(\'name\')]'
            }
          }
          template: loadJsonContent('../templates/AssignUAI/deploy.json')
        }
      }
    }
  }
}

module policyDefinition_CSE '../../deployments/sharedModules/resources/authorization/policy-definition/main.bicep' = {
  name: 'dep-PolicyDefinition-RunScripts'
  params: {
    name: policyDefinitionNameCSE
    mode: 'Indexed'
    displayName: policyDefinitionDisplayNameCSE
    description: policyDefinitionDescriptionCSE
    subscriptionId: subscriptionId
    parameters: {
      fileUris: {
        type: 'Array'
        metadata: {
          displayName: 'File Uris'
          description: 'An array of file URIs to download. The format can be either files must be accessible and not require authentication.'
          strongType: 'uri'
          portalReview: true
        }
      }
      scriptToRun: {
        type: 'String'
        metadata: {
          displayName: 'Script To Run'
          description: 'The script file name to execute after downloading. This file must be in the list of fileUris.'
          portalReview: true
        }
      }
      scriptArguments: {
        type: 'String'
        metadata: {
          displayName: 'Script Arguments'
          description: 'The arguments to pass to the script. If no arguments are needed, leave blank.'
          portalReview: true
        }
      }
      userAssignedIdentityResourceId: {
        type: 'String'
        defaultValue: ''
        metadata: {
          displayName: 'User Assigned Identity Resource ID'
          description: 'The Resource ID of the user assigned identity that has access to the artifactsUri.'
          strongType: 'Microsoft.ManagedIdentity/userAssignedIdentities'
          portalReview: true
        }
      }
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
        effect: 'DeployIfNotExists'
        details: {
          type: 'Microsoft.Compute/virtualMachines/extensions'
          name: 'AzurePolicyforWindows'
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
          roleDefinitionIds: [
            '/providers/microsoft.authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
          ]
        }
        deployment: {
          properties: {
            mode: 'Incremental'
            parameters: {
              fileUris: {
                value: '[parameters(\'fileUris\')]'
              }
              location: '[field(\'location\')]'
              scriptToRun: {
                value: '[parameters(\'scriptToRun\')]'
              }
              scriptArguments: {
                value: '[parameters(\'scriptArguments\')]'
              }
              userAssignedIdentityResourceId: {
                value: '[parameters(\'userAssignedIdentityResourceId\')]'
              }
              vmname: '[field(\'name\')]'
            }         
          template: loadJsonContent('../templates/CSE/deploy.json')
        }
        }
      }
    }
  }
}

module policySetDefinition '../../deployments/sharedModules/resources/authorization/policy-set-definition/main.bicep' = {
  name: 'dep-PolicySetDefinition'
  params: {
    name: policySetDefinitionName
    displayName: policySetDefinitionDisplayName
    description: policySetDefinitionDescription
    subscriptionId: subscriptionId
    parameters: {
      BlobContainerUri: {
        type: 'string'
        metadata: {
          displayName: 'Blob Container Uri'
          #disable-next-line no-hardcoded-env-urls
          description: 'This will be the Azure Storage Blob Container Url (e.g. "https://storageaccount.blob.core.windows.net/containername")'
        }
      }
      BlobNamesOrUris: {
        type: 'array'
        metadata: {
          displayName: 'Blob Names or File Uris'
          description: 'An array list of Blobs or full Uris to each file you wish to download via the Custom Script Extension in the order of download.'
          portalReview: true
        }
        defaultValue: []
      }
      ScriptToExecute: {
        type: 'string'
        metadata: {
          displayName: 'Script To Execute'
          description: 'The name of the PowerShell script to execute via the Custom Script Extension. This script must be in the list of Blob Names or File Uris'
          portalReview: true
        }
      }
      ScriptArguments: {
        type: 'string'
        metadata: {
          displayName: 'Script Arguments'
          description: 'PowerShell Script Arguments'
          portalReview: true
        }
        defaultValue: ''
      }
      UserAssignedIdentity: {
        type: 'string'
        metadata: {
          displayName: 'User-Assigned Identity'
          description: 'The Resource ID of the user assigned identity that has access to the artifactsUri.'
          strongType: 'Microsoft.ManagedIdentity/userAssignedIdentities'
          portalReview: true
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: policyDefinition_AUAI.outputs.resourceId
        policyDefinitionReferenceId: policyDefinitionDisplayNameAUAI
        parameters: {
          userAssignedIdentityResourceId: {
            value: '[parameters(\'UserAssignedIdentity\')]'
          }
        }
        groupNames: []
      }
      {
        policyDefinitionId: policyDefinition_CSE.outputs.resourceId
        policyDefinitionReferenceId: policyDefinitionDisplayNameCSE
        parameters: {
          artifactsUri: {
            value: '[parameters(\'BlobContainerUri\')]'
          }
          fileUris: {
            value: '[parameters(\'BlobNamesOrUris\')]'
          }
          scriptToRun: {
            value: '[parameters(\'ScriptToExecute\')]'
          }
          scriptArguments: {
            value: '[parameters(\'ScriptArguments\')]'
          }
          userAssignedIdentityResourceId: {
            value: '[parameters(\'UserAssignedIdentity\')]'
          }
        }
        groupNames: []
      }
    ]
  }
}
