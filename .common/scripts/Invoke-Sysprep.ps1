$Services = 'RdAgent', 'WindowsTelemetryService', 'WindowsAzureGuestAgent'        
ForEach ($Service in $Services) {
    If (Get-Service | Where-Object {$_.Name -eq $Service}) {
        While ((Get-Service -Name $Service).Status -ne 'Running') {
            Write-Output ">>> Waiting for $Service to start..."
            Start-Sleep -Seconds 5
        }
    }
}
$Files = "$env:SystemRoot\System32\sysprep\unattend.xml", "$env:SystemRoot\Panther\Unattend.xml"
ForEach ($file in $Files) {
    if (Test-Path -Path $File) {
      Write-Output ">>> Removing $file"
      Remove-Item $file -Force
    }
}
Write-Output '>>> Sysprepping VM ...'
Start-Process -FilePath "C:\Windows\System32\Sysprep\Sysprep.exe" -ArgumentList "/generalize /oobe /quit /mode:vm" -Wait
while($true) {
    $imageState = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State).ImageState
    Write-Output $imageState
    if ($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { break }
    Start-Sleep -s 5
}
Write-Output ">>> Sysprep complete ..."