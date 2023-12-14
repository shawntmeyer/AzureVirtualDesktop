targetScope = 'subscription'
param ActiveDirectorySolution string
param ArtifactsLocation string
param ArtifactsStorageAccountResourceId string
param ArtifactsUserAssignedIdentityResourceId string
param AutomationAccountName string
param Availability string
param AvdObjectId string
param LocationControlPlane string
param DataCollectionRulesName string
param DesktopFriendlyName string
param DiskNamePrefix string
param DiskEncryptionOptions object
param DiskEncryptionSetName string
param DiskSku string
@secure()
param DomainJoinUserPassword string
@secure()
param DomainJoinUserPrincipalName string
param DomainName string
param DrainMode bool
param Environment string
param Fslogix bool
param FslogixSolution string
param FslogixStorage string
param HostPoolType string
param KerberosEncryption string
param KeyVaultName string
param LocationVirtualMachines string
param LogAnalyticsWorkspaceName string
param LogAnalyticsWorkspaceRetention int
param LogAnalyticsWorkspaceSku string
param Monitoring bool
param NetworkInterfaceNamePrefix string
param PooledHostPool bool
param RecoveryServices bool
param RecoveryServicesVaultName string
param ResourceGroupControlPlane string
param ResourceGroupManagement string
param ResourceGroupStorage string
param RoleDefinitions object
param ScalingTool bool
param SessionHostCount int
param StorageSolution string
param SubnetResourceId string
param Tags object
param Timestamp string
param TimeZone string
param UserAssignedIdentityName string
param VirtualMachineMonitoringAgent string
param VirtualMachineNamePrefix string
@secure()
param VirtualMachineAdminPassword string
@secure()
param VirtualMachineAdminUserName string
param VirtualMachineSize string
param WorkspaceFriendlyName string
param WorkspaceName string

var CpuCountMax = contains(HostPoolType, 'Pooled') ? 32 : 128
var CpuCountMin = contains(HostPoolType, 'Pooled') ? 4 : 2
var VirtualNetworkName = split(SubnetResourceId, '/')[8]
var VirtualNetworkResourceGroupName = split(SubnetResourceId, '/')[4]
var DefaultValidationParameters = '-CpuCountMax ${CpuCountMax} -CpuCountMin ${CpuCountMin} -Environment ${environment().name} -Location ${LocationVirtualMachines} -SessionHostCount ${SessionHostCount} -StorageSolution ${StorageSolution} -SubscriptionId ${subscription().subscriptionId} -TenantId ${tenant().tenantId} -UserAssignedIdentityClientId ${userAssignedIdentity.outputs.clientId} -VirtualMachineSize ${VirtualMachineSize} -VirtualNetworkName ${VirtualNetworkName} -VirtualNetworkResourceGroupName ${VirtualNetworkResourceGroupName} -WorkspaceName ${WorkspaceName} -WorkspaceResourceGroupName ${ResourceGroupManagement}'
var ValidationScriptParameters = ActiveDirectorySolution == 'AzureActiveDirectoryDomainServices' ? '-DomainName ${DomainName} -KerberosEncryption ${KerberosEncryption} ${DefaultValidationParameters}' : DefaultValidationParameters

module userAssignedIdentity 'userAssignedIdentity.bicep' = {
  scope: resourceGroup(ResourceGroupManagement)
  name: 'UserAssignedIdentity_${Timestamp}'
  params: {
    ArtifactsStorageAccountResourceId: ArtifactsStorageAccountResourceId
    ArtifactsUserAssignedIdentityResourceId: ArtifactsUserAssignedIdentityResourceId
    DiskEncryptionSet: DiskEncryptionOptions.DiskEncryptionSet
    DrainMode: DrainMode
    Fslogix: Fslogix
    FslogixStorage: FslogixStorage
    Location: LocationVirtualMachines    
    UserAssignedIdentityName: UserAssignedIdentityName
    ResourceGroupStorage: ResourceGroupStorage
    ResourceGroupControlPlane: ResourceGroupControlPlane
    ScalingTool: ScalingTool
    Tags: contains(Tags, 'Microsoft.ManagedIdentity/userAssignedIdentities') ? Tags['Microsoft.ManagedIdentity/userAssignedIdentities'] : {}
    Timestamp: Timestamp
    VirtualNetworkResourceGroupName: split(SubnetResourceId, '/')[4]
  }
}

// Role Assignment for Validation
// This role assignment is required to collect validation information
resource roleAssignment_validation 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(UserAssignedIdentityName, RoleDefinitions.Reader, subscription().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitions.Reader)
    principalId: userAssignedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment_UpdateDesktopFriendlyName 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(DesktopFriendlyName)) {
  name: guid(UserAssignedIdentityName, RoleDefinitions.DesktopVirtualizationApplicationGroupContributor, subscription().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitions.DesktopVirtualizationApplicationGroupContributor)
    principalId: userAssignedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

module keyVault 'keyVault.bicep' =  {
  name: 'KeyVault_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    DiskEncryptionOptions: DiskEncryptionOptions
    DiskEncryptionSetName: DiskEncryptionSetName
    DomainJoinUserPassword: DomainJoinUserPassword
    DomainJoinUserPrincipalName: DomainJoinUserPrincipalName   
    Environment: Environment
    KeyVaultName: KeyVaultName
    Location: LocationVirtualMachines
    TagsDiskEncryptionSet: contains(Tags, 'Microsoft.Compute/diskEncryptionSets') ? Tags['Microsoft.Compute/diskEncryptionSets'] : {}
    TagsKeyVault: contains(Tags, 'Microsoft.KeyVault/vaults') ? Tags['Microsoft.KeyVault/vaults'] : {}
    Timestamp: Timestamp
    VirtualMachineAdminPassword: VirtualMachineAdminPassword
    VirtualMachineAdminUserName: VirtualMachineAdminUserName
  }
}

resource keyVault_Ref 'Microsoft.KeyVault/vaults@2023-07-01' existing = if(contains(ActiveDirectorySolution,'DomainServices') && (empty(DomainJoinUserPassword) || empty(DomainJoinUserPrincipalName)) || empty(VirtualMachineAdminPassword) || empty(VirtualMachineAdminUserName)) {
  name: KeyVaultName
  scope: resourceGroup(ResourceGroupManagement)
}

// Management VM
// The management VM is required to validate the deployment and configure FSLogix storage.
module virtualMachine 'virtualMachine.bicep' = {
  name: 'ManagementVirtualMachine_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    ActiveDirectorySolution: ActiveDirectorySolution
    ArtifactsLocation: ArtifactsLocation
    DiskEncryptionOptions: DiskEncryptionOptions
    DiskEncryptionSetResourceId: DiskEncryptionOptions.DiskEncryptionSet ? keyVault.outputs.diskEncryptionSetResourceId : ''
    DiskNamePrefix: DiskNamePrefix
    DiskSku: DiskSku
    DomainJoinUserPassword: !empty(DomainJoinUserPassword) ? DomainJoinUserPassword : contains(ActiveDirectorySolution, 'DomainServices') ? keyVault_Ref.getSecret('DomainJoinUserPassword') : ''
    DomainJoinUserPrincipalName: !empty(DomainJoinUserPrincipalName) ? DomainJoinUserPrincipalName : contains(ActiveDirectorySolution, 'DomainServices') ? keyVault_Ref.getSecret('DomainJoinUserPrincipalName') : ''
    DomainName: DomainName
    Location: LocationVirtualMachines
    NetworkInterfaceNamePrefix: NetworkInterfaceNamePrefix
    Subnet: split(SubnetResourceId, '/')[10]
    TagsNetworkInterfaces: contains(Tags, 'Microsoft.Network/networkInterfaces') ? Tags['Microsoft.Network/networkInterfaces'] : {}
    TagsVirtualMachines: contains(Tags, 'Microsoft.Compute/virtualMachines') ? Tags['Microsoft.Compute/virtualMachines'] : {}
    UserAssignedIdentityClientId: !empty(ArtifactsUserAssignedIdentityResourceId) ? userAssignedIdentity.outputs.ArtifactsUserAssignedIdentityClientId : userAssignedIdentity.outputs.clientId
    UserAssignedIdentityResourceIds: !empty(ArtifactsUserAssignedIdentityResourceId) ? {
      '${ArtifactsUserAssignedIdentityResourceId}' : {}
      '${userAssignedIdentity.outputs.id}' : {}
     } : {
      '${userAssignedIdentity.outputs.id}' : {}
     }
    VirtualNetwork: VirtualNetworkName
    VirtualNetworkResourceGroup: VirtualNetworkResourceGroupName
    VirtualMachineNamePrefix: VirtualMachineNamePrefix
    VirtualMachineAdminPassword: VirtualMachineAdminPassword
    VirtualMachineAdminUserName: VirtualMachineAdminUserName
  }
}

// Deployment Validations
// This module validates the selected parameter values and collects required data
module validations 'customScriptExtensions.bicep' = {
  scope: resourceGroup(ResourceGroupManagement)
  name: 'Validations_${Timestamp}'
  params: {
    ArtifactsLocation: ArtifactsLocation
    ExecuteScript: 'Get-Validations.ps1'
    Files: ['Get-Validations.ps1']
    Location: LocationVirtualMachines
    Output: true
    Parameters: ValidationScriptParameters
    Tags: contains(Tags, 'Microsoft.Compute/virtualMachines') ? Tags['Microsoft.Compute/virtualMachines'] : {}
    UserAssignedIdentityClientId: !empty(ArtifactsUserAssignedIdentityResourceId) ? userAssignedIdentity.outputs.ArtifactsUserAssignedIdentityClientId : userAssignedIdentity.outputs.clientId
    VirtualMachineName: virtualMachine.outputs.Name
  }
}

// Role Assignment required for Start VM On Connect
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(AvdObjectId, RoleDefinitions.DesktopVirtualizationPowerOnContributor, subscription().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitions.DesktopVirtualizationPowerOnContributor)
    principalId: AvdObjectId
  }
}

// Monitoring Resources for AVD Insights
// This module deploys a Log Analytics Workspace and if Monitoring agent is the legacy Log Analytics Agent then the Windows Events & Windows Performance Counters plus diagnostic settings on the required resources 
module logAnalyticsWorkspace 'logAnalyticsWorkspace.bicep' = if (Monitoring) {
  name: 'LogAnalytics_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    LogAnalyticsWorkspaceName: LogAnalyticsWorkspaceName
    LogAnalyticsWorkspaceRetention: LogAnalyticsWorkspaceRetention
    LogAnalyticsWorkspaceSku: LogAnalyticsWorkspaceSku
    Location: LocationControlPlane
    Tags: contains(Tags, 'Microsoft.OperationalInsights/workspaces') ? Tags['Microsoft.OperationalInsights/workspaces'] : {}
    VirtualMachineMonitoringAgent: VirtualMachineMonitoringAgent
  }
}

// Data Collection Rule for AVD Insights required for the Azure Monitor Agent
module dataCollectionRules 'avdInsightsDataCollectionRules.bicep' = if (VirtualMachineMonitoringAgent == 'AzureMonitorAgent') {
  name: 'DataCollectionRule_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    LogAWorkspaceId: logAnalyticsWorkspace.outputs.ResourceId
    Location: LocationControlPlane
    Name: DataCollectionRulesName
    Tags: contains(Tags, 'Microsoft.Insights/dataCollectionRules') ? Tags['Microsoft.Insights/dataCollectionRules'] : {}
  }
}

// Automation Account required for the AVD Scaling Tool and the Auto Increase Premium File Share Quota solution
module automationAccount 'automationAccount.bicep' = if (PooledHostPool || contains(FslogixSolution, 'AzureFiles Premium')) {
  name: 'AutomationAccount_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    AutomationAccountName: AutomationAccountName
    Location: LocationVirtualMachines
    LogAnalyticsWorkspaceResourceId: Monitoring ? logAnalyticsWorkspace.outputs.ResourceId : ''
    Monitoring: Monitoring
    Tags: contains(Tags, 'Microsoft.Automation/automationAccounts') ? Tags['Microsoft.Automation/automationAccounts'] : {}
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

module recoveryServicesVault 'recoveryServicesVault.bicep' = if (RecoveryServices) {
  name: 'RecoveryServicesVault_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    Fslogix: Fslogix
    Location: LocationVirtualMachines
    RecoveryServicesVaultName: RecoveryServicesVaultName
    StorageSolution: StorageSolution
    Tags: contains(Tags, 'Microsoft.RecoveryServices/vaults') ? Tags['Microsoft.RecoveryServices/vaults'] : {}
    TimeZone: TimeZone
  }
}

module workspace 'workspace.bicep' = {
  name: 'Workspace_Create_${Timestamp}'
  scope: resourceGroup(ResourceGroupManagement)
  params: {
    ApplicationGroupReferences: []
    Existing: validations.outputs.value.existingWorkspace == 'true' ? true : false
    FriendlyName: WorkspaceFriendlyName
    Location: LocationControlPlane
    LogAnalyticsWorkspaceResourceId: Monitoring ? logAnalyticsWorkspace.outputs.ResourceId : ''
    Monitoring: Monitoring
    Tags: contains(Tags, 'Microsoft.DesktopVirtualization/workspaces') ? Tags['Microsoft.DesktopVirtualization/workspaces'] : {}
    Timestamp: Timestamp
    WorkspaceName: WorkspaceName
  }
}

output ArtifactsUserAssignedIdentityClientId string = userAssignedIdentity.outputs.ArtifactsUserAssignedIdentityClientId
output KeyVaultResourceId string = keyVault.outputs.keyVaultResourceId
output KeyVaultUrl string = keyVault.outputs.keyVaultUrl
output DataCollectionRulesResourceId string = VirtualMachineMonitoringAgent == 'AzureMonitorAgent' ? dataCollectionRules.outputs.dataCollectionRulesId : ''
output DiskEncryptionSetResourceId string = keyVault.outputs.diskEncryptionSetResourceId
output EncryptionKeyResourceId string = keyVault.outputs.keyId
output EncryptionKeyUrl string = keyVault.outputs.keyUrl
output LogAnalyticsWorkspaceResourceId string = Monitoring ? logAnalyticsWorkspace.outputs.ResourceId : ''
output UserAssignedIdentityClientId string = userAssignedIdentity.outputs.clientId
output UserAssignedIdentityResourceId string = userAssignedIdentity.outputs.id
output ValidateAcceleratedNetworking string = validations.outputs.value.acceleratedNetworking
output ValidateANFfActiveDirectory string = validations.outputs.value.anfActiveDirectory
output ValidateANFDnsServers string = validations.outputs.value.anfDnsServers
output ValidateANFSubnetId string = validations.outputs.value.anfSubnetId
output ValidateAvailabilityZones array = Availability == 'AvailabilityZones' ? validations.outputs.value.availabilityZones : [ '1' ]
output ValidateTrustedLaunch string = validations.outputs.value.trustedLaunch
output VirtualMachineName string = virtualMachine.outputs.Name
