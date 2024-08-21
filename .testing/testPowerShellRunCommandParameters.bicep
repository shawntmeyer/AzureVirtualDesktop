param arrayValues array = [
  'value1'
  'value2'
  'value3'
]

param virtualMachineName string = 'test4va'



module runCommand '../deployments/sharedModules/resources/compute/virtual-machine/runCommand/main.bicep' = {
  name: 'RunCommand5'
  params: {
    parameters: [
      {
        name: 'stringValue2'
        value: string(arrayValues)
      }     
    ]
    script: loadTextContent('testRunCommand.ps1')    
    virtualMachineName: virtualMachineName
    name: 'testRunCommand5'
  }
}
