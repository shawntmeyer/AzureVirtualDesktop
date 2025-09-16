[CmdletBinding()]
param (
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string]$Location,
    [bool]$createResourceGroup = $true,
    [bool]$createNetwork = $true,
    [bool]$createCustomImage = $true,
    [bool]$createHostPool = $true,
    [bool]$CreateAddOns = $true,
    [bool]$UpdateBicep = $true
)

$ErrorActionPreference = 'Stop'

$InstallPath = Join-Path -Path $env:USERPROFILE -ChildPath '.bicep'
$Bicep = Join-Path -Path $InstallPath -ChildPath 'bicep.exe'

If ($UpdateBicep) {
    Write-Output 'Updating Bicep CLI'
    # Create the install folder
    $installDir = New-Item -ItemType Directory -Path $InstallPath -Force
    $installDir.Attributes += 'Hidden'
    # Fetch the latest Bicep CLI binary
    Write-Output "Downloading Bicep CLI to '$Bicep'."
    (New-Object Net.WebClient).DownloadFile("https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe", $Bicep)
    # Add bicep to your PATH
    $currentPath = (Get-Item -path "HKCU:\Environment" ).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    if (-not $currentPath.Contains("%USERPROFILE%\.bicep")) { setx PATH ($currentPath + ";%USERPROFILE%\.bicep") }
    if (-not $env:path.Contains($installPath)) { $env:path += ";$installPath" }
    $Version = (Get-Item $Bicep).VersionInfo.FileVersion
    Write-Output "Bicep CLI updated to Version: $Version"
    $BicepInstalled = $true
} Else {
    $BicepInstalled = Test-Path -Path $Bicep
    if ($BicepInstalled) {
        $Version = (Get-Item $Bicep).VersionInfo.FileVersion
        Write-Output "Bicep CLI found. Version: $Version"
    }
    else {
        Write-Output 'Bicep CLI not found. Please set $UpdateBicep to $true to download the latest version'
    }
}

$Context = Get-AzContext
If ($null -eq $Context) {
    Throw 'You are not logged in to Azure. Please login to azure before continuing'
    Exit
}

if ($null -eq $ResourceGroupName -or $ResourceGroupName -eq '') {
    Write-Output 'Resource Group Name not provided. Using default naming convention'
    $ResourceGroupName = "rg-templatespecs-$location"
    Write-Output "Resource Group Name: $ResourceGroupName"
}

if ($createResourceGroup) {
    Write-Output "Searching for Resource Group: $ResourceGroupName"
    if (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -eq $ResourceGroupName }) {
        Write-Output "Resource Group $ResourceGroupName already exists"
    }
    else {
        Write-Output "Resource Group $ResourceGroupName does not exist. Creating Resource Group"
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    }
}

if ($createNetwork) {
    Write-Output 'Creating AVD Networking Template Spec'
    If ($BicepInstalled) {
        $bicepFile = Join-Path $PSScriptRoot -ChildPath 'networking\networking.bicep'
        Write-Output "Transpiling Bicep file '$bicepFile' to JSON"
        Start-Process -FilePath $Bicep -ArgumentList "build $bicepFile" -Wait -NoNewWindow
    }
    $templateFile = Join-Path $PSScriptRoot -ChildPath 'networking\networking.json'
    $uiFormDefinition = Join-Path $PSScriptRoot -ChildPath 'networking\uiFormDefinition.json'
    New-AzTemplateSpec -ResourceGroupName $ResourceGroupName -Name 'AVD-Networking' -DisplayName 'Azure Virtual Desktop Networking' -Description 'Deploys the networking components to support Azure Virtual Desktop' -TemplateFile $templateFile -UiFormDefinitionFile $uiFormDefinition -Location $Location -Version '1.0.0' -Force
}

if ($createCustomImage) {
    If ($BicepInstalled) {
        $bicepFile = Join-Path -Path $PSScriptRoot -ChildPath 'imageManagement\imageBuild\imageBuild.bicep'
        Write-Output "Transpiling Bicep file '$bicepFile' to JSON"
        Start-Process -FilePath $Bicep -ArgumentList "build $bicepFile" -Wait -NoNewWindow
    }
    Write-Output 'Creating AVD Custom Image Template Spec'
    $templateFile = Join-Path -Path $PSScriptRoot -ChildPath 'imageManagement\imageBuild\imageBuild.json'
    $uiFormDefinition = Join-Path -Path $PSScriptRoot -ChildPath 'imageManagement\imageBuild\uiFormDefinition.json'
    New-AzTemplateSpec -ResourceGroupName $ResourceGroupName -Name 'AVD-CustomImage' -DisplayName 'Azure Virtual Desktop Custom Image' -Description 'Generates a custom image for Azure Virtual Desktop' -TemplateFile $templateFile -UiFormDefinitionFile $uiFormDefinition -Location $Location -Version '1.0.0' -Force
}

if ($createHostPool) {
    If ($BicepInstalled) {
        $bicepFile = Join-Path -Path $PSScriptRoot -ChildPath 'hostpools\hostpool.bicep'
        Write-Output "Transpiling Bicep file '$bicepFile' to JSON"
        Start-Process -FilePath $Bicep -ArgumentList "build $bicepFile" -Wait -NoNewWindow
    }
    $templateFile = Join-Path -Path $PSScriptRoot -ChildPath 'hostpools\hostpool.json'
    $uiFormDefinition = Join-Path -Path $PSScriptRoot -ChildPath 'hostpools\uiFormDefinition.json'
    Write-Output 'Creating AVD Host Pool Template Spec'
    New-AzTemplateSpec -ResourceGroupName $ResourceGroupName -Name 'AVD-HostPool' -DisplayName 'Azure Virtual Desktop Host Pool' -Description 'Deploys an Azure Virtual Desktop Host Pool' -TemplateFile $templateFile -UiFormDefinitionFile $uiFormDefinition -Location $Location -Version '1.0.0' -Force
}

if ($CreateAddOns) {
    If ($BicepInstalled) {
        $bicepFile = Join-Path -Path $PSScriptRoot -ChildPath 'add-ons\RunCommandsOnVms\main.bicep'
        Write-Output "Transpiling Bicep file '$bicepFile' to JSON"
        Start-Process -FilePath $Bicep -ArgumentList "build $bicepFile" -Wait -NoNewWindow
    }
    $templateFile = Join-Path -Path $PSScriptRoot -ChildPath 'add-ons\RunCommandsOnVms\main.json'
    $uiFormDefinition = Join-Path -Path $PSScriptRoot -ChildPath 'add-ons\RunCommandsOnVms\uiFormDefinition.json'
    Write-Output 'Creating Run Commands on VMs Template Spec'
    New-AzTemplateSpec -ResourceGroupName $ResourceGroupName -Name 'RunCommandsOnVMs' -DisplayName 'Run Commands on VMs' -Description 'Run scripts on Virtual Machines' -TemplateFile $templateFile -UiFormDefinitionFile $uiFormDefinition -Location $Location -Version '1.0.0' -Force
}
Write-Output "Template Specs Created. You can now find them in the Azure Portal in the '$ResourceGroupName' resource group"