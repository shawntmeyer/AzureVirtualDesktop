[CmdletBinding()]
param (
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string]$Location,
    [bool]$createResourceGroup = $true,
    [bool]$createNetwork = $true,
    [bool]$createCustomImage = $true,
    [bool]$createHostPool = $true,
    [bool]$CreateAddOns = $true
)

$ErrorActionPreference = 'Stop'

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
    $templateFile = Join-Path $PSScriptRoot -ChildPath 'networking\networking.json'
    $uiFormDefinition = Join-Path $PSScriptRoot -ChildPath 'networking\uiFormDefinition.json'
    New-AzTemplateSpec -ResourceGroupName $ResourceGroupName -Name 'AVD-Networking' -DisplayName 'Azure Virtual Desktop Networking' -Description 'Deploys the networking components to support Azure Virtual Desktop' -TemplateFile $templateFile -UiFormDefinitionFile $uiFormDefinition -Location $Location -Version '1.0.0' -Force
}

if ($createCustomImage) {
    Write-Output 'Creating AVD Custom Image Template Spec'
    $templateFile = Join-Path -Path $PSScriptRoot -ChildPath 'imageManagement\imageBuild\imageBuild.json'
    $uiFormDefinition = Join-Path -Path $PSScriptRoot -ChildPath 'imageManagement\imageBuild\uiFormDefinition.json'
    New-AzTemplateSpec -ResourceGroupName $ResourceGroupName -Name 'AVD-CustomImage' -DisplayName 'Azure Virtual Desktop Custom Image' -Description 'Generates a custom image for Azure Virtual Desktop' -TemplateFile $templateFile -UiFormDefinitionFile $uiFormDefinition -Location $Location -Version '1.0.0' -Force
}

if ($createHostPool) {
    $templateFile = Join-Path -Path $PSScriptRoot -ChildPath 'hostpools\hostpool.json'
    $uiFormDefinition = Join-Path -Path $PSScriptRoot -ChildPath 'hostpools\uiFormDefinition.json'
    Write-Output 'Creating AVD Host Pool Template Spec'
    New-AzTemplateSpec -ResourceGroupName $ResourceGroupName -Name 'AVD-HostPool' -DisplayName 'Azure Virtual Desktop Host Pool' -Description 'Deploys an Azure Virtual Desktop Host Pool' -TemplateFile $templateFile -UiFormDefinitionFile $uiFormDefinition -Location $Location -Version '1.0.0' -Force
}

if ($CreateAddOns) {
    $templateFile = Join-Path -Path $PSScriptRoot -ChildPath 'add-ons\RunCommandsOnVms\main.json'
    $uiFormDefinition = Join-Path -Path $PSScriptRoot -ChildPath 'add-ons\RunCommandsOnVms\uiFormDefinition.json'
    Write-Output 'Creating Run Commands on VMs Template Spec'
    New-AzTemplateSpec -ResourceGroupName $ResourceGroupName -Name 'RunCommandsOnVMs' -DisplayName 'Run Commands on VMs' -Description 'Run scripts on Virtual Machines' -TemplateFile $templateFile -UiFormDefinitionFile $uiFormDefinition -Location $Location -Version '1.0.0' -Force
}
Write-Output "Template Specs Created. You can now find them in the Azure Portal in the '$ResourceGroupName' resource group"