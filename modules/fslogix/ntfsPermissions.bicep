param ArtifactsLocation string
@secure()
param CommandToExecute string
param Location string
param ManagementVmName string
param TagsVirtualMachines object
param Timestamp string
param UserAssignedIdentityClientId string

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: '${ManagementVmName}/CustomScriptExtension'
  location: Location
  tags: TagsVirtualMachines
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${ArtifactsLocation}Set-NtfsPermissions.ps1'
      ]
      timestamp: Timestamp
    }
    protectedSettings: !empty(UserAssignedIdentityClientId) ? {
      managedIdentity: {
        clientId: UserAssignedIdentityClientId
      }
      commandToExecute: CommandToExecute
    } : {
      commandToExecute: CommandToExecute
    }
  }
}
