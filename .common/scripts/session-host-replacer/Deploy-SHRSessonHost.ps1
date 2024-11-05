function Deploy-SHRSessionHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ResourceManagerUrl,

        [Parameter(Mandatory = $true)]
        [psobject] $RestHeader,

        [Parameter(Mandatory = $true)]
        [string] $SubscriptionId,

        [Parameter()]
        [string[]] $ExistingSessionHostVMNames = @(),

        [Parameter(Mandatory = $true)]
        [int] $NewSessionHostsCount,

        [Parameter(Mandatory = $false)]
        [string] $HostPoolResourceGroupName = (Get-FunctionConfig _HostPoolResourceGroupName),

        [Parameter(Mandatory = $true)]
        [string] $SessionHostResourceGroupName,

        [Parameter()]
        [string] $HostPoolName = (Get-FunctionConfig _HostPoolName),

        [Parameter()]
        [string] $SessionHostNamePrefix = (Get-FunctionConfig _SessionHostNamePrefix),

        [Parameter()]
        [string] $SessionHostNameSeparator = (Get-FunctionConfig _SessionHostNameSeparator),

        [Parameter()]
        [int] $SessionHostInstanceNumberPadding = (Get-FunctionConfig _SessionHostInstanceNumberPadding),

        [Parameter()]
        [string] $DeploymentPrefix = (Get-FunctionConfig _SHRDeploymentPrefix),


        [Parameter()]
        [string] $SessionHostTemplate = (Get-FunctionConfig _SessionHostTemplate),

        [Parameter()]
        [string] $SessionHostTemplateParametersPS1Uri = (Get-FunctionConfig _SessionHostTemplateParametersPS1Uri),

        [Parameter()]
        [string] $TagIncludeInAutomation = (Get-FunctionConfig _Tag_IncludeInAutomation),
        [Parameter()]
        [string] $TagDeployTimestamp = (Get-FunctionConfig _Tag_DeployTimestamp),

        [Parameter()]
        [hashtable] $SessionHostParameters = (Get-FunctionConfig _SessionHostParameters | ConvertTo-CaseInsensitiveHashtable), #TODO: Port this into AzureFunctionConfiguration module and make it ciHashtable type.

        [Parameter()]
        [string] $VMNamesTemplateParameterName = (Get-FunctionConfig _VMNamesTemplateParameterName)
    )

    Write-OutputDetailed -Message "Generating new token for the host pool $HostPoolName in Resource Group $HostPoolResourceGroupName"
    $Body = @{
        properties = @{
            registrationInfo = @{
                expirationTime = (Get-Date).AddHours(8)
                registrationTokenOperation = 'Update'
            }
        }
    }
    Invoke-RestMethod `
        -Body ($Body | ConvertTo-Json -depth 10) `
        -Headers $RestHeader `
        -Method Post `
        -Uri ($ResourceManagerUrl + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $HostPoolResourceGroupName + '/providers/Microsoft.DesktopVirtualization/hostPools/' + $HostPoolName + '?api-version=2024-04-03') | Out-Null

    # $HostPoolToken = (Invoke-RestMethod -Headers $RestHeader -Method Get -Uri ($ResourceManagerUrl + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $HostPoolResourceGroupName + '/providers/Microsoft.DesktopVirtualization/hostPools/' + $HostPoolName + '/retrieveRegistrationToken?api-version=2024-04-03')).token

    # Calculate Session Host Names
    Write-OutputDetailed -Level Host -Message "Existing session host VM names: {0}" -StringValues ($ExistingSessionHostVMNames -join ',')
    [array] $sessionHostNames = for ($i = 0; $i -lt $NewSessionHostsCount; $i++) {
        $vmNumber = 1
        While (("$SessionHostNamePrefix$SessionHostNameSeparator{0:d$SessionHostInstanceNumberPadding}" -f $vmNumber) -in $ExistingSessionHostVMNames) {
            $vmNumber++
        }
        $vmName = "$SessionHostNamePrefix$SessionHostNameSeparator{0:d$SessionHostInstanceNumberPadding}" -f $vmNumber
        $ExistingSessionHostVMNames += $vmName
        $vmName
    }
    Write-OutputDetailed -Message "Creating session host(s) " + ($sessionHostNames -join ', ')

    # Update Session Host Parameters
    $sessionHostParameters[$VMNamesTemplateParameterName]   = $sessionHostNames
    $sessionHostParameters['Tags'][$TagIncludeInAutomation] = $true
    $sessionHostParameters['Tags'][$TagDeployTimestamp]     = (Get-Date -AsUTC -Format 'o')
    $deploymentTimestamp = Get-Date -AsUTC -Format 'FileDateTime'
    $deploymentName = "{0}_{1}_Count_{2}_VMs" -f $DeploymentPrefix, $deploymentTimestamp, $sessionHostNames.count
    
    Write-OutputDetailed -Message "Deployment name: $deploymentName"
    Write-OutputDetailed -Message "Deploying using Template Spec: $sessionHostTemplate"
    $templateSpecVersionResourceId = Get-SHRTemplateSpecVersionResourceId -ResourceId $SessionHostTemplate

    Write-OutputDetailed -Message "Deploying $NewSessionHostCount session host(s) to resource group $sessionHostResourceGroupName" 
    
    $Body = @{
        properties = @{
            parameters = $sessionHostParameters
            templateLink = @{
                id = $templateSpecVersionResourceId
            }
        }
    }
    $Uri = $ResourceManagerUrl + '/subscriptions/' + $SubscriptionId + '/resourceGroups/' + $SessionHostResourceGroupName + '/providers/Microsoft.Resources/deployments/' + $deploymentName + '?api-version=2021-04-01'
    $DeploymentJob = Invoke-RestMethod `
                        -Body ($Body | ConvertTo-Json -depth 10) `
                        -Headers $RestHeader `
                        -Method Put `
                        -Uri $Uri `
    #TODO: Add logic to test if deployment is running (aka template is accepted) then finish running the function and let the deployment run in the background.
    Write-LogDetailed -Message 'Pausing for 30 seconds to allow deployment to start'
    Start-Sleep -Seconds 30
    # Check deployment status, if any has failed we report an error
    if ($deploymentJob.Error) {
        Write-OutputDetailed "DeploymentFailed"
        throw $deploymentJob.Error
    }
}