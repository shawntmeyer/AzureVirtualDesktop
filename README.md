# Azure Virtual Desktop Solution

[**Home**](./readme.md) | [**Features**](./docs/features.md) | [**Design**](./docs/design.md) | [**Prerequisites**](./docs/prerequisites.md) | [**Post Deployment**](./docs/post.md) | [**Troubleshooting**](./docs/troubleshooting.md)

This Azure Virtual Desktop (AVD) solution will deploy a fully operational [stamp](https://learn.microsoft.com/azure/architecture/patterns/deployment-stamp) in an Azure subscription. Many of the [features](./docs/features.md) used with AVD have been automated in this solution for your convenience.  When deploying this solution be sure to read the [prerequisites](./docs/prerequisites.md) and the descriptions for each parameter to the understand the consequences of your selections.

## Deployment Options

> **WARNING**: Be sure to review the [prerequisites](./docs/prerequisites.md) before deploying this solution.

### Azure Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjamasten%2FAzureVirtualDesktop%2Fmain%2Fsolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fjamasten%2FAzureVirtualDesktop%2Fmain%2FuiDefinition.json)
[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjamasten%2FAzureVirtualDesktop%2Fmain%2Fsolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fjamasten%2FAzureVirtualDesktop%2Fmain%2FuiDefinition.json)

### PowerShell

````powershell
New-AzDeployment `
    -Location '<Azure location>' `
    -TemplateFile 'https://raw.githubusercontent.com/jamasten/AzureVirtualDesktop/main/solution.json' `
    -Verbose
````

### Azure CLI

````cli
az deployment sub create \
    --location '<Azure location>' \
    --template-uri 'https://raw.githubusercontent.com/jamasten/AzureVirtualDesktop/main/solution.json'
````  
