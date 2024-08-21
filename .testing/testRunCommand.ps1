[CmdletBinding()]
param (
    [Parameter()]
    [string]$stringValue,
    [string]$stringValue2,
    [array]$arrayValues
)

Write-Host $stringValue