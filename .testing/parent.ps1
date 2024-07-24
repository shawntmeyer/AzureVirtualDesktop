#$ErrorActionPreference = 'stop'
$Path = 'c:\Repos'
$Script = 'Child.ps1'
$FullPath = Join-Path -Path $PSScriptRoot -ChildPath $Script
$Null = & $FullPath -Path $Path
Write-Output "Script Completed"