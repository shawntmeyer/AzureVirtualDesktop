[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $Path
)

$Dirs = Get-ChildItem -Path $Path
Write-Output $Dirs

Write-Output "Child Done"
#Write-Error "Error $_"