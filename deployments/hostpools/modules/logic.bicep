targetScope = 'subscription'

param identitySolution string
param artifactsUri string
param avdAgentInstallersBlobName string
param avdPrivateLink bool
param dedicatedHostGroupResourceId string
param dedicatedHostResourceId string
param deployScalingPlan bool = false
param diskSku string
param domainName string
param cseBlobNames array
param cseMasterScript string
param deployFSLogixStorage bool
param fileShareNames object
param fslogixConfigureSessionHosts bool
param fslogixConfigurationBlobName string
param fslogixContainerType string
param fslogixStorageService string
param hostPoolOnly bool = false
param hostPoolType string = 'Pooled DepthFirst'
param imageOffer string
param imagePublisher string
param imageSku string
param locations object
param locationVirtualMachines string
param resourceGroupControlPlane string
param resourceGroupGlobalFeed string
param resourceGroupHosts string
param resourceGroupManagement string
param resourceGroupMonitoring string
param resourceGroupStorage string
param scalingPlanExclusionTag string
param scalingPlanRampUpSchedule object = {}
param scalingPlanPeakSchedule object = {}
param scalingPlanRampDownSchedule object = {}
param scalingPlanOffPeakSchedule object = {}
param scalingPlanForceLogoff bool = false
param scalingPlanMinsBeforeLogoff int = 0
param securityPrincipals array
param sessionHostCount int
param sessionHostIndex int
param tags object
param fslogixStorageCount int
param virtualMachineNamePrefix string
param virtualMachineSize string

var dedicatedHostGroupName = !empty(dedicatedHostResourceId) ? split(dedicatedHostResourceId, '/')[8] : !empty(dedicatedHostGroupResourceId) ? last(split(dedicatedHostGroupResourceId, '/')) : '' 
var dedicatedHostRG = !empty(dedicatedHostResourceId) ? split(dedicatedHostResourceId, '/')[4] : !empty(dedicatedHostGroupResourceId) ? split(dedicatedHostGroupResourceId, '/')[4] : '' 

resource dedicatedHostGroup 'Microsoft.Compute/HostGroups@2020-12-01' existing = if(!empty(dedicatedHostGroupName)) {
  scope: resourceGroup(dedicatedHostRG)
  name: dedicatedHostGroupName
}

var scalingPlanSchedules = deployScalingPlan ? [
  {
    rampUpStartTime: {
      hour: first(split(scalingPlanRampUpSchedule.startTime, ':')[0]) == '0' ? int(last(split(scalingPlanRampUpSchedule.startTime, ':')[0])) : int(split(scalingPlanRampUpSchedule.startTime, ':')[0])
      minute: first(split(scalingPlanRampUpSchedule.startTime, ':')[1]) == '0' ? int(last(split(scalingPlanRampUpSchedule.startTime, ':')[1])) : int(split(scalingPlanRampUpSchedule.startTime, ':')[1])
    }
    peakStartTime: {
      hour: first(split(scalingPlanPeakSchedule.startTime, ':')[0]) == '0' ? int(last(split(scalingPlanPeakSchedule.startTime, ':')[0])) : int(split(scalingPlanPeakSchedule.startTime, ':')[0])
      minute: first(split(scalingPlanPeakSchedule.startTime, ':')[1]) == '0' ? int(last(split(scalingPlanPeakSchedule.startTime, ':')[1])) : int(split(scalingPlanPeakSchedule.startTime, ':')[1])
    }
    rampDownStartTime: {
      hour: first(split(scalingPlanRampDownSchedule.startTime, ':')[0]) == '0' ? int(last(split(scalingPlanRampDownSchedule.startTime, ':')[0])) : int(split(scalingPlanRampDownSchedule.startTime, ':')[0])
      minute: first(split(scalingPlanRampDownSchedule.startTime, ':')[1]) == '0' ? int(last(split(scalingPlanRampDownSchedule.startTime, ':')[1])) : int(split(scalingPlanRampDownSchedule.startTime, ':')[1])
    }
    offPeakStartTime: {
      hour: first(split(scalingPlanOffPeakSchedule.startTime, ':')[0]) == '0' ? int(last(split(scalingPlanOffPeakSchedule.startTime, ':')[0])) : int(split(scalingPlanOffPeakSchedule.startTime, ':')[0])
      minute: first(split(scalingPlanOffPeakSchedule.startTime, ':')[1]) == '0' ? int(last(split(scalingPlanOffPeakSchedule.startTime, ':')[1])) : int(split(scalingPlanOffPeakSchedule.startTime, ':')[1])
    }
    name: 'weekdays_schedule'
    daysOfWeek: [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday' ]
    rampUpLoadBalancingAlgorithm: scalingPlanRampUpSchedule.loadBalancingAlgorithm
    rampUpMinimumHostsPct: scalingPlanRampUpSchedule.minimumHostsPct
    rampUpCapacityThresholdPct: scalingPlanRampUpSchedule.capacityThresholdPct
    peakLoadBalancingAlgorithm: scalingPlanPeakSchedule.loadBalancingAlgorithm
    rampDownLoadBalancingAlgorithm: scalingPlanRampDownSchedule.loadBalancingAlgorithm
    rampDownMinimumHostsPct: scalingPlanRampDownSchedule.minimumHostsPct
    rampDownCapacityThresholdPct: scalingPlanRampDownSchedule.capacityThresholdPct
    rampDownForceLogoffUsers: scalingPlanForceLogoff
    rampDownWaitTimeMinutes:  scalingPlanMinsBeforeLogoff
    rampDownNotificationMessage: scalingPlanForceLogoff ? 'You will be logged off in ${scalingPlanMinsBeforeLogoff} minutes. Make sure to save your work.' : null
    rampDownStopHostsWhen: 'ZeroSessions'
    offPeakLoadBalancingAlgorithm: scalingPlanOffPeakSchedule.loadBalancingAlgorithm
  }
] : []

var exclusionTag = !empty(scalingPlanExclusionTag) ? {
  'Microsoft.Compute/virtualMachines': {
    '${scalingPlanExclusionTag}': ''
  }
} : {}

var varTags = !empty(exclusionTag) ? union(tags, exclusionTag) : tags

//  BATCH SESSION HOSTS
// The following variables are used to determine the batches to deploy any number of AVD session hosts.
var maxResourcesPerTemplateDeployment = 79 // This is the max number of session hosts that can be deployed from the sessionHosts.bicep file in each batch / for loop. Math: (800 - <Number of Static Resources>) / <Number of Looped Resources> 
var divisionValue = sessionHostCount / maxResourcesPerTemplateDeployment // This determines if any full batches are required.
var divisionRemainderValue = sessionHostCount % maxResourcesPerTemplateDeployment // This determines if any partial batches are required.
var sessionHostBatchCount = divisionRemainderValue > 0 ? divisionValue + 1 : divisionValue // This determines the total number of batches needed, whether full and / or partial.

//  BATCH AVAILABILITY SETS
// The following variables are used to determine the number of availability sets.
var maxAvSetMembers = 200 // This is the max number of session hosts that can be deployed in an availability set.
var beginAvSetRange = sessionHostIndex / maxAvSetMembers // This determines the availability set to start with.
var endAvSetRange = (sessionHostCount + sessionHostIndex) / maxAvSetMembers // This determines the availability set to end with.
var availabilitySetsCount = length(range(beginAvSetRange, (endAvSetRange - beginAvSetRange) + 1))

// OTHER LOGIC & COMPUTED VALUES
// fslogix will not be configured on session hosts if identity solution is not EntraId. Decision made to lower complexity and to avoid potential issues. Assumes the use of Group Policy to configure FSlogix with Domain Services identity solution.
var fslogixConfigureHosts = identitySolution != 'EntraId' ? false : fslogixConfigureSessionHosts
var cseArtifacts = fslogixConfigureHosts ? union(['${cseMasterScript}'], ['${avdAgentInstallersBlobName}'], cseBlobNames, ['${fslogixConfigurationBlobName}']) : union(['${cseMasterScript}'], ['${avdAgentInstallersBlobName}'], cseBlobNames)
var cseUris = [ for artifact in cseArtifacts : contains(toLower(artifact), 'http') ? artifact : '${artifactsUri}${artifact}' ]

var fileShares = fileShareNames[fslogixContainerType]
// ONLY DEPLOY 1 storage account when Cloud Only identity is used because Sharding is not possible.
var countStorage = identitySolution == 'EntraId' || identitySolution == 'EntraIdIntuneEnrollment' ? 1 : fslogixStorageCount
var netbios = split(domainName, '.')[0]
var pooledHostPool = split(hostPoolType, ' ')[0] == 'Pooled' ? true : false

var resGroupHostPools = [
  resourceGroupControlPlane
  resourceGroupHosts
]

var resGroupBase = deployFSLogixStorage ? [
  resourceGroupControlPlane
  resourceGroupHosts
  resourceGroupManagement
  resourceGroupMonitoring
  resourceGroupStorage
] : [
  resourceGroupControlPlane
  resourceGroupHosts
  resourceGroupManagement
  resourceGroupMonitoring
]

var resourceGroupNames = hostPoolOnly ? resGroupHostPools : ( avdPrivateLink ? union([resourceGroupGlobalFeed], resGroupBase) : resGroupBase )

var roleDefinitions = {
  AutomationContributor: 'f353d9bd-d4a6-484e-a77a-8050b599b867'
  DesktopVirtualizationApplicationGroupContributor: '86240b0e-9422-4c43-887b-b61143f32ba8'
  DesktopVirtualizationPowerOnContributor: '489581de-a3bd-480d-9518-53dea7416b33'
  DesktopVirtualizationPowerOnOffContributor: '40c5ff49-9181-41f8-ae61-143b0e78555e'
  DesktopVirtualizationSessionHostOperator: '2ad6aaab-ead9-4eaa-8ac5-da422f562408'
  DesktopVirtualizationUser: '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'
  DesktopVirtualizationWorkspaceContributor: '21efdde3-836f-432b-bf3d-3e8e734d4b2b'
  KeyVaultCryptoServiceEncryptionUser: 'e147488a-f6f5-4113-8e2d-b22465e65bf6'
  KeyVaultCryptoServiceReleaseUser: '08bbd89e-9f13-488c-ac41-acfcb10c90ab'
  KeyVaultReader: '21090545-7ca7-4776-b22c-e363652d74d2'
  Reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  StorageAccountContributor: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  StorageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  VirtualMachineContributor: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
  VirtualMachineUserLogin: 'fb879df8-f326-4884-b1cf-06f3ad86be52'
}
var SecurityPrincipalsCount = length(securityPrincipals)
var smbServerLocation = locations[locationVirtualMachines].abbreviation
var fslogixStorageSku = fslogixStorageService == 'None' ? 'None' : split(fslogixStorageService, ' ')[1]
var fslogixStorageSolution = split(fslogixStorageService, ' ')[0]
var storageSuffix = environment().suffixes.storage
var timeDifference = locations[locationVirtualMachines].timeDifference
var timeZone = locations[locationVirtualMachines].timeZone
var virtualMachineTemplate = '{"domain":"${domainName}","galleryImageOffer":"${imageOffer}","galleryImagePublisher":"${imagePublisher}","galleryImageSKU":"${imageSku}","imageType":"Gallery","imageUri":null,"customImageId":null,"namePrefix":"${virtualMachineNamePrefix}","osDiskType":"${diskSku}","useManagedDisks":true,"virtualMachineSize":{"id":"${virtualMachineSize}","cores":null,"ram":null},"galleryItemId":"${imagePublisher}.${imageOffer}${imageSku}"}'

output availabilitySetsCount int = availabilitySetsCount
output beginAvSetRange int = beginAvSetRange
output cseUris array = cseUris
output dedicatedHostGroupZones array = !empty(dedicatedHostGroupName) ? dedicatedHostGroup.zones : []
output divisionRemainderValue int = divisionRemainderValue
output fileShares array = fileShares
output maxResourcesPerTemplateDeployment int = maxResourcesPerTemplateDeployment
output netbios string = netbios
output pooledHostPool bool = pooledHostPool
output resourceGroupNames array = resourceGroupNames
output roleDefinitions object = roleDefinitions
output scalingPlanSchedules array = scalingPlanSchedules
output sessionHostBatchCount int = sessionHostBatchCount
output SecurityPrincipalsCount int = SecurityPrincipalsCount
output smbServerLocation string = smbServerLocation
output fslogixStorageSku string = fslogixStorageSku
output fslogixStorageSolution string = fslogixStorageSolution
output fslogixConfigureSessionHosts bool = fslogixConfigureHosts
output storageSuffix string = storageSuffix
output fslogixStorageCount int = countStorage
output tags object = varTags
output timeDifference string = timeDifference
output timeZone string = timeZone
output virtualMachineTemplate string = virtualMachineTemplate
