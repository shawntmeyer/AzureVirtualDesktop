param automationAccountName string
param location string
param Name string
param Script string
@secure()
param ScriptContainerSasToken string
param ScriptContainerUri string
param tags object

resource automationAccount 'Microsoft.Automation/automationAccounts@2019-06-01' existing = {
  name: automationAccountName
}

resource runbooks 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccount
  name: Name
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    publishContentLink: {
      uri: '${ScriptContainerUri}${Script}?${ScriptContainerSasToken}'
      version: '1.0.0.0'
    }
  }
}
