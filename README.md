# Azure Virtual Desktop Solution

[**Home**](./README.md) | [**Features**](./docs/features.md) | [**Design**](./docs/design.md) | [**Prerequisites**](./docs/prerequisites.md) | [**Troubleshooting**](./docs/troubleshooting.md)

This solution will deploy a fully operational Azure Virtual Desktop hostpool and image management capability adhereing to the [Zero Trust principles](https://learn.microsoft.com/security/zero-trust/azure-infrastructure-avd). Many of the [common features](./docs/features.md) used with AVD have been automated in this solution for your convenience.

## Deployment Options

> [!WARNING]
> Failure to complete the [prerequisites](./docs/prerequisites.md) will result in an unsuccessful deployment.

### Blue Buttons

This option opens the deployment UI for the solution in the Azure Portal. Be sure to select the button for the correct cloud. If your desired cloud is not listed, please use the template spec option below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2Fazurevirtualdesktop%2Fmaster%2F%2Fdeployments%2Fhostpools%2FcompleteSolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2Fazurevirtualdesktop%2Fmaster%2F%2Fdeployments%2Fhostpools%2FcompleteSolution-UI.json)
[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2Fazurevirtualdesktop%2Fmaster%2F%2Fdeployments%2Fhostpools%2FcompleteSolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2Fazurevirtualdesktop%2Fmaster%2F%2Fdeployments%2Fhostpools%2FcompleteSolution-UI.json)

### Template Spec

This option creates a template spec in Azure to deploy the solution and is the preferred option for air-gapped clouds. Once you create the template spec, open it in the portal and click the "Deploy" button.

````powershell
$Location = '<Azure Location>'
$ResourceGroupName = 'rg-ts-<Environment Abbreviation>-<Location Abbreviation>'
$TemplateSpecName = 'ts-avd-<Environment Abbreviation>-<Location Abbreviation>'

New-AzResourceGroup `
    -Name $ResourceGroupName `
    -Location $Location `
    -Force

New-AzTemplateSpec `
    -ResourceGroupName $ResourceGroupName `
    -Name $TemplateSpecName `
    -Version 1.0 `
    -Location $Location `
    -TemplateFile '.\deployments\hostpools\completeSolution.json' `
    -UIFormDefinitionFile '.\deployments\hostpools\completeSolution-UI.json' `
    -Force
````