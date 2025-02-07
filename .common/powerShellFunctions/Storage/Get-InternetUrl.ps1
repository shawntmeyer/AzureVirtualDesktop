<#
.SYNOPSIS
Extract the download URL from a website based on a search string. Uses a matching search string by prepending and appending a wildcard character to the string.

.DESCRIPTION


.PARAMETER Url
Specifies the URI to search for a link.

.PARAMETER SearchString
Specifies the search string that is used to find a matching hyperlink. You can include a '*' for a wildcard in the search string.

.EXAMPLE
Get-InternetUrl -WebSiteUrl "http://www.microsoft.com/software/wvd" -SearchString "FSLogix"

Searches the provided website url for a hyperlink with the searchstring "FSLogix" contained in it and returns the url. 
#>

Function Get-InternetUrl {
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory,
            HelpMessage = "Specifies the website that contains a link to the desired download."
        )]
        [uri]$WebSiteUrl,

        [Parameter(
            Mandatory,
            HelpMessage = "Specifies the search string. Wildcard '*' can be used."    
        )]
        [string]$SearchString
    )

    Try {
        $HTML = Invoke-WebRequest -Uri $WebSiteUrl -UseBasicParsing
        $Links = $HTML.Links
        $ahref = $null
        $ahref=@()
        $ahref = ($Links | Where-Object {$_.href -like "*$searchstring*"})
        If ($ahref.count -eq 0 -or $null -eq $ahref) {
            $ahref = ($Links | Where-Object {$_.OuterHTML -like "*$searchstring*"})
        }
        If ($ahref.Count -gt 0) {
            Return $ahref[0].href
        }
        Else {
            $Pattern = '"url":\s*"(https://[^"]*?' + $SearchString.Replace('.', '\.').Replace('*', '.*').Replace('+', '\+') + ')"' 
            If ($HTML.Content -match $Pattern) {
                If ($matches[1].Contains('"')) {
                    Return $matches[1].Substring(0, $matches[1].IndexOf('"'))
                } Else {
                    Return $matches[1]
                }

            } else {
                Write-Warning "No download URL found using search term."
                Return $null
            }
        }
    }
    Catch {
        Write-Error "Error Downloading HTML and determining link for download."
        Return
    }
}