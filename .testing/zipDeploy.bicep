resource ZipDeploy 'Microsoft.Web/sites/extensions@2024-04-01' = {
  name: '${functionName}/ZipDeploy'
  properties: {
    packageUri: packageUri
  }
}
