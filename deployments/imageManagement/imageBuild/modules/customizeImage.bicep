targetScope = 'resourceGroup'

param cloud string
param location string = resourceGroup().location


param artifactsContainerUri string
param customizations array
param logBlobContainerUri string
param managementVmName string
param imageVmName string
param installFsLogix bool
param fslogixSetupBlobName string
param installAccess bool
param installExcel bool
param installOneNote bool
param installOutlook bool
param installPowerPoint bool
param installProject bool
param installPublisher bool
param installSkypeForBusiness bool
param installTeams bool
param installUpdates bool
param installVirtualDesktopOptimizationTool bool
param installVisio bool
param installWord bool
param installOneDrive bool
param onedriveSetupBlobName string
param vDotBlobName string
param officeDeploymentToolBlobName string
param removeApps bool
param teamsInstallerBlobName string
param teamsCloudType string
param timeStamp string = utcNow('yyMMddhhmm')
param updateService string
param userAssignedIdentityClientId string
param wsusServer string

var buildDir = 'c:\\BuildDir'

var apiVersion = environment().name == 'USNat' ? '2017-08-01' : '2018-02-01'

var customizers = [for customization in customizations: {
  name: replace(customization.name, ' ', '-')
  uri: contains(customization.blobNameOrUri, '//:') ? customization.blobNameOrUri : '${artifactsContainerUri}/${customization.blobNameOrUri}'
  arguments: customization.?arguments ?? ''
}]

var commonScriptParams = [
  {
    name: 'APIVersion'
    value: apiVersion
  }
  {
    name: 'BlobStorageSuffix'
    value: 'blob.${environment().suffixes.storage}'
  }
  {
    name: 'BuildDir'
    value: buildDir
  }
  {
    name: 'UserAssignedIdentityClientId'
    value: userAssignedIdentityClientId
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
    treatFailureAsDeploymentFailure: true
  }

}

resource removeAppxPackages 'Microsoft.Compute/virtualMachines/runCommands@2024-03-01' = if (removeApps) {
  name: 'remove-appxPackages'
  location: location
  parent: imageVm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Remove-AppxPackages-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${imageVmName}-Remove-AppxPackages-output-${timeStamp}.log'
    source: {
      script: loadTextContent('../../../../.common/scripts/Remove-AppXPackages.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
}

@batchSize(1)
resource applications 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = [for customizer in customizers: {
  name: customizer.name
  location: location
  parent: imageVm
  properties: {
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
        name: 'Uri'
        value: customizer.uri
      }
      {
        name: 'Name'
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
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    createBuildDirs
    removeAppxPackages
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
        name: 'Name'
        value: 'FSLogix'
      }
      {
        name: 'Uri'
        value: contains(fslogixSetupBlobName, '//:') ? fslogixSetupBlobName : '${artifactsContainerUri}/${fslogixSetupBlobName}'
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Install-FSLogix.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    createBuildDirs
    removeAppxPackages
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
        name: 'Name'
        value: 'Office-365-ProPlus'
      }
      {
        name: 'Uri'
        value: contains(officeDeploymentToolBlobName, '//:') ? officeDeploymentToolBlobName : '${artifactsContainerUri}/${officeDeploymentToolBlobName}'
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Install-M365Applications.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    createBuildDirs
    removeAppxPackages
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
        name: 'Name'
        value: 'OneDrive'
      }
      {
        name: 'Uri'
        value: contains(onedriveSetupBlobName, '//:') ? onedriveSetupBlobName : '${artifactsContainerUri}/${onedriveSetupBlobName}'
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Install-OneDrive.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    createBuildDirs
    removeAppxPackages
    applications
    fslogix
    office
  ]
}

resource teams 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installTeams) {
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
        name: 'Name'
        value: 'Teams'
      }      
      {
        name: 'Uri'
        value: contains(teamsInstallerBlobName, '//:') ? teamsInstallerBlobName : '${artifactsContainerUri}/${teamsInstallerBlobName}'
      }
      {
        name: 'TeamsCloudType'
        value: teamsCloudType
      }  
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Install-Teams.ps1')
    }
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    createBuildDirs
    removeAppxPackages
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
    removeAppxPackages
    applications
    fslogix
    office
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
        name: 'Name'
        value: 'VDOT'
      }
      {
        name: 'Uri'
        value: contains(vDotBlobName, '//:') ? vDotBlobName : '${artifactsContainerUri}/${vDotBlobName}'
      }
    ])
    source: {
      script: loadTextContent('../../../../.common/scripts/Invoke-VDOT.ps1')
    }
    timeoutInSeconds: 640
    treatFailureAsDeploymentFailure: true
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
