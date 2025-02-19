param(
    [string]$BuildDir=''
)

If ($BuildDir -ne '' -and (Test-Path -Path $BuildDir)) {Remove-Item -Path $BuildDir -Recurse -Force | Out-Null}
Get-ChildItem -Path $env:SystemDrive -Include *.tmp, *.dmp, *.etl, *.evtx, thumbcache*.db, *.log -File -Exclude $env:SystemRoot\Logs\* -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
Get-ChildItem -Path $env:ProgramData\Microsoft\Windows\RetailDemo\* -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $env:windir\Temp\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $env:ProgramData\Microsoft\Windows\WER\Temp\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $env:ProgramData\Microsoft\Windows\WER\ReportArchive\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $env:ProgramData\Microsoft\Windows\WER\ReportQueue\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Clear-BCCache -Force -ErrorAction SilentlyContinue
