$Date = Get-Date -Format 'yyyyMMddhhmmss'

$Prefixes = @('CustomPrefix1')
$DeploymentJobs = @()
ForEach ($Prefix in $Prefixes) {
    $ParameterFile = Join-Path -Path $PSScriptRoot -ChildPath "imageManagement\imageBuild\parameters\$Prefix.imagebuild.parameters.json"
    If (Test-Path -Path $ParameterFile) {
        Write-Output "Using parameter file: $ParameterFile"
        $DeploymentJobs += New-AzDeployment -Name "ImageBuild-$Prefix-$Date" -Location 'eastus2' -TemplateFile (Join-Path -Path $PSScriptRoot -ChildPath 'imageManagement\imageBuild\imageBuild.json') -TemplateParameterFile $ParameterFile -AsJob 
    }
    else {
        Write-Error "Parameter file $ParameterFile does not exist. Please create the parameter file and try again."
        exit
    }
}

Wait-Job -Job $DeploymentJobs
Receive-Job -Job $DeploymentJobs