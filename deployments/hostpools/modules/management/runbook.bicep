param artifactsUri string
param automationAccountName string
param blobName string
param location string
param purpose string
param tags object
param userAssignedIdentityClientId string
param artifactsUserAssignedIdentityClientId string
param virtualMachineName string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: virtualMachineName
}

resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2023-07-01' = {
  name: 'runbook-${purpose}'
  location: location
  tags: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}
  parent: virtualMachine
  properties: {
    treatFailureAsDeploymentFailure: true
    asyncExecution: false
    parameters: [
      {
        name: 'ArtifactsUri'
        value: artifactsUri
      }
      {
        name: 'AutomationAccountName'
        value: automationAccountName
      }
      {
        name: 'BlobName'
        value: blobName
      }
      {
        name: 'Environment'
        value: environment().name
      }
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'SubscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'TenantId'
        value: tenant().tenantId
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ArtifactsUserAssignedIdentityClient'
        value: artifactsUserAssignedIdentityClientId
      }
    ]
    source: {
      script: '''
        param (
          [string]$ArtifactsUri,
          [string]$ArtifactsUserAssignedIdentityObjectId,
          [string]$AutomationAccountName,
          [string]$BlobName,
          [string]$Environment,
          [string]$ResourceGroupName,
          [string]$SubscriptionId,
          [string]$TenantId,
          [string]$UserAssignedIdentityClientId
        )
        $ErrorActionPreference = 'Stop'
        $WarningPreference = 'SilentlyContinue'
        $RunbookName = $BlobName.Replace('.ps1','')
        $ContainerName = $ArtifactsUri.Split('/')[3]
        $StorageAccountUrl = $ArtifactsUri.Replace("/$ContainerName/", '')
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&client_id=$ArtifactsUserAssignedIdentityClientId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $File = "$env:windir\temp\$BlobName"
        do
        {
            try
            {
                Write-Output "Download Attempt $i"
                Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$ArtifactsUri$BlobName" -OutFile $File
            }
            catch [System.Net.WebException]
            {
                Start-Sleep -Seconds 60
                $i++
                if($i -gt 10){throw}
                continue
            }
            catch
            {
                $Output = $_ | select *
                Write-Output $Output
                throw
            }
        }
        until(Test-Path -Path $File)
        Connect-AzAccount -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId -Identity -AccountId $UserAssignedIdentityClientId | Out-Null
        Import-AzAutomationRunbook -Name $RunbookName -Path $File -Type PowerShell -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Published -Force | Out-Null
        Start-Sleep -Seconds 30
      '''
    }
  }
}
