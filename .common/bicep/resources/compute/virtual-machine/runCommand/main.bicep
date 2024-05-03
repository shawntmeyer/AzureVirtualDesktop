metadata name = 'Virtual Machine RunCommand'
metadata description = 'This module deploys a Virtual Machine Run Command.'
metadata owner = 'shawn.meyer@microsoft.com'

@description('Conditional. The name of the parent virtual machine that extension is provisioned for. Required if the template is used in a standalone deployment.')
param virtualMachineName string

@description('Required. The name of the virtual machine extension.')
param name string

@description('Optional. The location the extension is deployed to.')
param location string = resourceGroup().location

@description('Optional.  If set to true, provisioning will complete as soon as the script starts and will not wait for script to complete.')
param asyncExecution bool = false

@description('''Optional. User-assigned managed identity that has access to errorBlobContainerUri storage blob container.
Use an empty object in case of system-assigned identity. Make sure managed identity has been given access to blob\'s container with \'Storage Blob Data Contributor\' role assignment.
In case of user-assigned identity, make sure you add it under VM's identity.
For more info on managed identity and Run Command, refer https://aka.ms/ManagedIdentity and https://aka.ms/RunCommandManaged''')
param errorBlobManagedIdentity object = {}

@description('''Optional. 	Specifies the Azure storage blob where script error stream will be uploaded.
Use a SAS URI with read, append, create, write access OR use managed identity to provide the VM access to the blob.
Refer errorBlobManagedIdentity parameter.''')
param errorBlobContainerUri string = ''

@description('''Optional. User-assigned managed identity that has access to outputBlobContainerUri storage blob container.
Use an empty object in case of system-assigned identity. Make sure managed identity has been given access to blob\'s container with \'Storage Blob Data Contributor\' role assignment.
In case of user-assigned identity, make sure you add it under VM's identity.
For more info on managed identity and Run Command, refer https://aka.ms/ManagedIdentity and https://aka.ms/RunCommandManaged''')
param outputBlobManagedIdentity object = {}

@description('''Optional. 	Specifies the Azure storage blob where script error stream will be uploaded.
Use a SAS URI with read, append, create, write access OR use managed identity to provide the VM access to the blob.
Refer errorBlobManagedIdentity parameter.''')
param outputBlobContainerUri string = ''

@description('Optional. Parameters used by the script.')
param parameters array = []

@description('Optional. Protected parameters used by the script. These parameters will not show up in deployment data.')
param protectedParameters array = []

@description('Optional. Specifies the user account password on the VM when executing the run command.')
@secure()
param runAsPassword string = ''

@description('Optional. Specifies the user account on the VM when executing the run command.')
param runAsUser string = ''

@description('Conditional. Specifies a commandId of predefined built-in script. Do not use with [script] or [scriptUri] parameters.')
param commandId string = ''

@description('Optional. Specifies the script content to be executed on the VM. Do not use with [commandId] or [scriptUri] parameters.')
param script string = ''

@description('''Optional. Specifies the script download location. It can be either SAS URI of an Azure storage blob with read access or public URI.
Do not use with [commandId] or [script] parameters.''')
param scriptUri string = ''

@description('''Optional. User-assigned managed identity that has access to scriptUri in case of Azure storage blob.
Use an empty object in case of system-assigned identity.
Make sure the Azure storage blob exists, and managed identity has been given access to blob's container with 'Storage Blob Data Reader' role assignment.
In case of user-assigned identity, make sure you add it under VM's identity.
For more info on managed identity and Run Command, refer https://aka.ms/ManagedIdentity and https://aka.ms/RunCommandManaged.''')
param scriptUriManagedIdentity object = {}

@description('Optional. The timeout in seconds to execute the run command.')
param timeoutInSeconds int = -1

@description('''Optional. Optional. If set to true, any failure in the script will fail the deployment and ProvisioningState will be marked as Failed.
If set to false, ProvisioningState would only reflect whether the run command was run or not by the extensions platform, it would not indicate whether script failed in case of script failures.
See instance view of run command in case of script failures to see executionMessage, output, error: https://aka.ms/runcommandmanaged#get-execution-status-and-results''')
param treatFailureAsDeploymentFailure bool = false

@description('Optional. Tags of the resource.')
param tags object = {}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: virtualMachineName
}

resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: name
  location: location
  tags: tags
  parent: virtualMachine
  properties: {
    asyncExecution: asyncExecution
    errorBlobManagedIdentity: !empty(errorBlobManagedIdentity) ? errorBlobManagedIdentity : null
    errorBlobUri: !empty(errorBlobContainerUri) ? '${toLower(errorBlobContainerUri)}${name}-error.log' : null
    outputBlobManagedIdentity: !empty(outputBlobManagedIdentity) ? outputBlobManagedIdentity : null
    outputBlobUri: !empty(outputBlobContainerUri) ? '${toLower(outputBlobContainerUri)}${name}-output.log' : null
    parameters: !empty(parameters) ? parameters : null
    protectedParameters: !empty(protectedParameters) ? protectedParameters : null
    runAsPassword: !empty(runAsPassword) ? runAsPassword : null
    runAsUser: !empty(runAsUser) ? runAsUser : null
    source: {
      commandId: !empty(commandId) ? commandId : null
      script: !empty(script) ? script : null
      scriptUri: !empty(scriptUri) ? scriptUri : null
      scriptUriManagedIdentity: !empty(scriptUriManagedIdentity) ? scriptUriManagedIdentity : null
    }
    timeoutInSeconds: timeoutInSeconds != -1 ? timeoutInSeconds : null
    treatFailureAsDeploymentFailure: treatFailureAsDeploymentFailure
  }
}

output outputStream string = runCommand.properties.instanceView.output
output exitCode int = runCommand.properties.instanceView.exitCode
