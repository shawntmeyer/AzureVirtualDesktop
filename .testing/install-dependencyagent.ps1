$VMs = Get-AzVM -ResourceGroupName 'TT-DevTop-AVD-RG'
ForEach ($VM in $VMs) {
    $VMName = $VM.Name
    Set-AzVMExtension -ExtensionName "DependencyAgentWindows" `
        -ResourceGroupName "TT-DEVTOP-AVD-RG" `
        -VMName "$VMName" `
        -Publisher "Microsoft.Azure.monitoring.DependencyAgent" `
        -ExtensionType "DependencyAgentWindows" `
        -TypeHandlerVersion 9.10 `
        -location 'USGov Virginia' `
        -EnableAutomaticUpgrade $true
}

$VMNames = $VMs.Names

New-AzResourceGroupDeployment -Name 'AzureMonitorAgent' -location 'USGov Virginia' -TemplateFile 'C:\Users\ShawnMeyer\Repos\MissionTenants\Environments\TWILIGHTTOWER\AVD\modules\sessionHosts\azureMonitorAgent.bicep' -VMNames $VMNames