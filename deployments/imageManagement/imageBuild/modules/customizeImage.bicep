targetScope = 'resourceGroup'

param cloud string
param location string = resourceGroup().location
param userAssignedIdentityClientId string
param logBlobContainerUri string
param storageEndpoint string
param artifactsContainerName string
param managementVmName string
param imageVmName string
param installFsLogix bool
param fslogixBlobName string
param installAccess bool
param installExcel bool
param installOneNote bool
param installOutlook bool
param installPowerPoint bool
param installProject bool
param installPublisher bool
param installSkypeForBusiness bool
param installTeams bool
param installVirtualDesktopOptimizationTool bool
param installVisio bool
param installWord bool
param installOneDrive bool
param onedriveBlobName string
param customizations array
param vDotBlobName string
param officeBlobName string
param teamsBlobName string
param teamsCloudType string
param teamsVersion string
param timeStamp string = utcNow('yyMMddhhmm')
param installUpdates bool
param updateService string
param wsusServer string

var buildDir = 'c:\\BuildDir'

var apiVersion = environment().name == 'USNat' ? '2017-08-01' : '2018-02-01'

var customizers = [for customization in customizations: {
  name: replace(customization.name, ' ', '-')
  blobName: customization.blobName
  arguments: contains(customization, 'arguments') ? customization.arguments : ''
}]

var commonScriptParams = [
  {
    name: 'APIVersion'
    value: apiVersion
  }
  {
    name: 'BuildDir'
    value: buildDir
  }
  {
    name: 'UserAssignedIdentityClientId'
    value: userAssignedIdentityClientId
  }
  {
    name: 'ContainerName'
    value: artifactsContainerName
  }
  {
    name: 'StorageEndpoint'
    value: storageEndpoint
  }
]

var restartVMParameters = [
  {
    name: 'ResourceManagerUri'
    value: environment().resourceManager
  }
  {
    name: 'UserAssignedIdentityClientId'
    value: userAssignedIdentityClientId
  }
  {
    name: 'VmResourceId'
    value: imageVm.id
  }
]

resource imageVm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: imageVmName
}

resource managementVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource createBuildDirs 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'create-BuildDir-and-LogDir'
  location: location
  parent: imageVm
  properties: {
    treatFailureAsDeploymentFailure: true
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
    ]
    source: {
      script: '''
        param(
          [string]$BuildDir
        )
        New-Item -Path $BuildDir -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path "$env:SystemRoot\Logs" -ChildPath ImageBuild) -ItemType Directory -Force | Out-Null
      '''
    }
  }
}

@batchSize(1)
resource applications 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = [for customizer in customizers: {
  name: customizer.name
  location: location
  parent: imageVm
  properties: {
    treatFailureAsDeploymentFailure: true
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-${customizer.name}-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-${customizer.name}-output-${timeStamp}.log'
    parameters: union(commonScriptParams, [      
      {
        name: 'Blobname'
        value: customizer.blobName
      }
      {
        name: 'installer'
        value: customizer.name
      }
      {
        name: 'Arguments'
        value: customizer.arguments
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Invoke-Customizations.ps1')
    }
  }
  dependsOn: [
    createBuildDirs
  ]
}]

resource fslogix 'Microsoft.Compute/virtualMachines/runCommands@2023-07-01' = if(installFsLogix) {
  name: 'fslogix'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-FSLogix-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-FSLogix-output-${timeStamp}.log'
    parameters: union(commonScriptParams, [
      {
        name: 'BlobName'
        value: fslogixBlobName
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Install-FSLogix.ps1')
    }
  }
  dependsOn: [
    createBuildDirs
    applications
  ]
}

resource office 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if(installAccess || installExcel || installOneNote || installOutlook || installPowerPoint || installProject || installPublisher || installSkypeForBusiness || installVisio || installWord) {
  name: 'm365Apps'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Office-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Office-output-${timeStamp}.log'
    parameters: union(commonScriptParams, [
      {
        name: 'Environment'
        value: cloud
      }
      {
        name: 'InstallAccess'
        value: string(installAccess)
      }
      {
        name: 'InstallWord'
        value: string(installWord)
      }
      {
        name: 'InstallExcel'
        value: string(installExcel)
      }
      {
        name: 'InstallOneNote'
        value: string(installOneNote)
      }
      {
        name: 'InstallOutlook'
        value: string(installOutlook)
      }
      {
        name: 'InstallPowerPoint'
        value: string(installPowerPoint)
      }
      {
        name: 'InstallProject'
        value: string(installProject)
      }
      {
        name: 'InstallPublisher'
        value: string(installPublisher)
      }
      {
        name: 'InstallSkypeForBusiness'
        value: string(installSkypeForBusiness)
      }
      {
        name: 'InstallVisio'
        value: string(installVisio)
      }
      {
        name: 'BlobName'
        value: officeBlobName
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Install-M365Applications.ps1')
    }
  }
  dependsOn: [
    createBuildDirs
    fslogix
    applications
  ]
}

resource onedrive 'Microsoft.Compute/virtualMachines/runCommands@2023-07-01' = if(installOneDrive) {
  name: 'onedrive'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-OneDrive-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-OneDrive-output-${timeStamp}.log'
    parameters: union(commonScriptParams, [
      {
        name: 'BlobName'
        value: onedriveBlobName
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Install-OneDrive.ps1')
    }
  }
  dependsOn: [
    createBuildDirs
    applications
    fslogix
    office
  ]
}

resource teamsClassic 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installTeams && teamsVersion == 'Classic') {
  name: 'teamsClassic'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Teams-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Teams-output-${timeStamp}.log'
    parameters: union(commonScriptParams, [
      {
        name: 'Environment'
        value: cloud
      }
      {
        name: 'BlobName'
        value: teamsBlobName
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Install-TeamsClassic.ps1')
    }
  }
  dependsOn: [
    createBuildDirs
    applications
    fslogix
    office
    onedrive
  ]
}

resource teams 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installTeams && teamsVersion == 'New') {
  name: 'teams'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Teams-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Teams-output-${timeStamp}.log'
    parameters: union(commonScriptParams, [
      {
        name: 'TeamsCloudType'
        value: teamsCloudType
      }     
      {
        name: 'BlobName'
        value: teamsBlobName
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Install-Teams.ps1')
    }
  }
  dependsOn: [
    createBuildDirs
    applications
    fslogix
    office
    onedrive
  ]
}

resource firstImageVmRestart 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'restart-vm-1'
  location: location
  parent: managementVm
  properties: {    
    asyncExecution: false
    parameters: restartVMParameters
    source: {
      script: loadTextContent('../../../../.common/scripts/Restart-Vm.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    createBuildDirs
    applications
    fslogix
    office
    teamsClassic
    teams
  ]
}

resource microsoftUpdates 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if(installUpdates) {
  name: 'microsoft-updates'
  location: location
  parent: imageVm
  properties: {
    asyncExecution: false
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Install-Updates-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Install-Updates-output-${timeStamp}.log'
    parameters: updateService == 'WSUS' ? [
      {
        name: 'Service'
        value: updateService
      }
      {
        name: 'WSUSServer'
        value: wsusServer
      }
    ] : [
      {
        name: 'Service'
        value: updateService
      }
    ]   
    source: {
      script: loadTextContent('../../../../.common/scripts/Invoke-WindowsUpdate.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    firstImageVmRestart
  ]
}

resource secondImageVmRestart 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if(installUpdates) {
  name: 'restart-vm-2'
  location: location
  parent: managementVm
  properties: {    
    asyncExecution: false
    parameters: restartVMParameters
    source: {
      script: loadTextContent('../../../../.common/scripts/Restart-Vm.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    microsoftUpdates
  ]
}

resource vdot 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installVirtualDesktopOptimizationTool) {
  name: 'vdot'
  location: location
  parent: imageVm
  properties: {
    treatFailureAsDeploymentFailure: true
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-vdot-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-vdot-output-${timeStamp}.log'
    parameters: union(commonScriptParams, [
      {
        name: 'BlobName'
        value: vDotBlobName
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Invoke-VDOT.ps1')
    }
    timeoutInSeconds: 640
  }
  dependsOn: [
    secondImageVmRestart
  ]
}

resource removeBuildDir 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'remove-BuildDir'
  location: location
  parent: imageVm
  properties: {
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
    ]
    source: {
      script: '''
        param(
          [string]$BuildDir
        )
        Remove-Item -Path $BuildDir -Recurse -Force | Out-Null
      '''
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    secondImageVmRestart
    vdot
  ]
}

resource thirdImageVmRestart 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installVirtualDesktopOptimizationTool) {
  name: 'restart-vm-3'
  location: location
  parent: managementVm
  properties: {    
    asyncExecution: false
    parameters: restartVMParameters
    source: {
      script: loadTextContent('../../../../.common/scripts/Restart-Vm.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    removeBuildDir
  ]
}

resource sysprep 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'sysprep'
  location: location
  parent: imageVm
  properties: {
    asyncExecution: false
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
        clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Sysprep-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
        clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Sysprep-output-${timeStamp}.log'
    source: {
      script: loadTextContent('../../../../.common/scripts/Invoke-Sysprep.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    removeBuildDir
    thirdImageVmRestart
  ]
}
