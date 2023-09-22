<#
.SYNOPSIS
Downloads the file located at the specified url and saves it to the output file location.

.DESCRIPTION
Downloads the file located at the specified url and saves it to the output file location.

.PARAMETER Url
Specifies the URI to search for a link.

.PARAMETER OutputFile
Specifies the search string that is used to find a matching hyperlink.

.EXAMPLE
Get-InternetFile -Url "aka.ms/fslogix_install" -OutputFile "c:\temp\FSLogix.zip"

#>

Function Get-InternetFile {
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory,
            HelpMessage = "The Uniform Resource Location for the download."
        )]
        [uri]$url,
        [Parameter(
            Mandatory,
            HelpMessage = "The output file name including path."    
        )]
        [string]$outputfile

    )

    $start_time = Get-Date 
    $wc = New-Object System.Net.WebClient
    Write-Verbose "Downloading file at '$url' to '$outputfile'."
    Try {
        $wc.DownloadFile($url, $outputfile)
    
        $time = (Get-Date).Subtract($start_time).Seconds
        
        Write-Verbose "Time taken: '$time' seconds."
        if (Test-Path -Path $outputfile) {
            $totalSize = (Get-Item $outputfile).Length / 1MB
            Write-Verbose "Download was successful. Final file size: '$totalsize' mb"
        }
    }
    Catch {
        Write-Error "Error downloading file. Please check url."
        Return
    }
}