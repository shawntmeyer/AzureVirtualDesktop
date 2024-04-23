param vmnames array = [
    'TT-Sensor-1'
    'TT-Sensor-2'
    'TT-Sensor-3'
    'TT-Sensor-4'
    'TT-Sensor-5'
    'TT-Sensor-6'
    'TT-Sensor-7'
    'TT-Sensor-8'
    'TT-Sensor-9'
    'TT-Sensor-10'
    'TT-Sensor-11'
    'TT-Sensor-12'
    'TT-Sensor-13'
    'TT-Sensor-14'

]
param location string
param depPrefix string = deployment().name
param scriptcontent string = '''
Param
(
    [Parameter(Mandatory = $false)]
    [Hashtable] $DynParameters
)

Function Get-InternetFile {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [uri]$Url,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$OutputDirectory,
        [Parameter(Mandatory = $false, Position = 2)]
        [string]$OutputFileName
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Verbose "Starting ${CmdletName} with the following parameters: $PSBoundParameters"
    }
    Process {

        $start_time = Get-Date

        If (!$OutputFileName) {
            Write-Verbose "${CmdletName}: No OutputFileName specified. Trying to get file name from URL."
            If ((split-path -path $Url -leaf).Contains('.')) {

                $OutputFileName = split-path -path $url -leaf
                Write-Verbose "${CmdletName}: Url contains file name - '$OutputFileName'."
            }
            Else {
                Write-Verbose "${CmdletName}: Url does not contain file name. Trying 'location' Response Header."
                $request = [System.Net.WebRequest]::Create($url)
                $request.AllowAutoRedirect=$false
                $response=$request.GetResponse()
                $location = $response.GetResponseHeader("location")
                If ($location) {
                    $OutputFileName = [System.IO.Path]::GetFileName($location)
                    Write-Verbose "${CmdletName}: File Name from 'location' Response Header is '$OutputFileName'."
                }
                Else {
                    Write-Verbose "${CmdletName}: No 'location' Response Header returned. Trying 'Content-Disposition' Response Header."
                    $result = Invoke-WebRequest -Method GET -Uri $Url -UseBasicParsing
                    $contentDisposition = $result.Headers.'Content-Disposition'
                    If ($contentDisposition) {
                        $OutputFileName = $contentDisposition.Split("=")[1].Replace("`"","")
                        Write-Verbose "${CmdletName}: File Name from 'Content-Disposition' Response Header is '$OutputFileName'."
                    }
                }
            }
        }

        If ($OutputFileName) { 
            $wc = New-Object System.Net.WebClient
            $OutputFile = Join-Path $OutputDirectory $OutputFileName
            Write-Verbose "${CmdletName}: Downloading file at '$url' to '$OutputFile'."
            Try {
                $wc.DownloadFile($url, $OutputFile)
                $time = (Get-Date).Subtract($start_time).Seconds
                
                Write-Verbose "${CmdletName}: Time taken: '$time' seconds."
                if (Test-Path -Path $outputfile) {
                    $totalSize = (Get-Item $outputfile).Length / 1MB
                    Write-Verbose "${CmdletName}: Download was successful. Final file size: '$totalsize' mb"
                    Return $OutputFile
                }
            }
            Catch {
                Write-Error "${CmdletName}: Error downloading file. Please check url."
                Return $Null
            }
        }
        Else {
            Write-Error "${CmdletName}: No OutputFileName specified. Unable to download file."
            Return $Null
        }
    }
    End {
        Write-Verbose "Ending ${CmdletName}"
    }
}

$SoftwareName = 'AzCLI'
$DownloadUrl = 'https://aka.ms/installazurecliwindows'
[String]$Script:LogDir = "$($env:SystemRoot)\Logs\Software"
If (-not(Test-Path -Path $Script:LogDir)) {
    New-Item -Path $Script:LogDir -ItemType Dir -Force
}
[string]$Script:LogName = "Install-$($SoftwareName.Replace(' ','')).log"
Start-Transcript -Path "$Script:LogDir\$Script:LogName" -Force

$pathmsi = (Get-ChildItem -Path $PSScriptRoot -filter '*.msi').FullName
If (!$pathmsi) {
    Write-output "Downloading '$SoftwareName' from '$DownloadUrl'."
    $TempDir = Join-Path $env:Temp -ChildPath $SoftwareName
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
    $pathmsi = Get-InternetFile -Url $DownloadUrl -OutputDirectory $TempDir
}
Write-output "Starting '$SoftwareName' installation and configuration."         
Write-output "Installing '$SoftwareName' via cmdline:"
Write-output "     'msiexec.exe /i `"$pathMSI`" /quiet'"
$Installer = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$pathMSI`" /quiet" -Wait -PassThru
If ($($Installer.ExitCode) -eq 0) {
    Write-output "'$SoftwareName' installed successfully."
}
Else {
    Write-Error "The Installer exit code is $($Installer.ExitCode)"
}
If ($tempDir) { Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue }
Write-output "Completed '$SoftwareName' Installation."
Stop-Transcript
'''

module runcommands '../../../Common/Bicep/ResourceModules/compute/virtual-machine/runCommand/main.bicep' = [for vm in vmnames: {
  name: '${depPrefix}-runcommand-${vm}'
  params: {
    location: location
    name: depPrefix
    virtualMachineName: vm
    script: scriptcontent
  }
}]
