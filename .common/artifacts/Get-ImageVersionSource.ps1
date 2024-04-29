[Cmdletbinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$UserAssignedIdentityClientId,

    [Parameter(Mandatory=$true)]
    [string]$ImageDefinitionResourceId,

    [Parameter(Mandatory=$true)]
    [string]$VmName,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$Location
)

function Write-Log {
    param(
        [parameter(Mandatory)]
        [string]$Message,
        
        [parameter(Mandatory)]
        [string]$Type
    )
    $Path = "$env:Temp\cse.txt"
    if(!(Test-Path -Path $Path))
    {
        New-Item -Path $Path -ItemType file | Out-Null
    }
    $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
    $Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
    $Entry | Out-File -FilePath $Path -Append
}

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

Connect-AzAccount -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId -Identity -AccountId $UserAssignedIdentityClientId | Out-Null

$Vm = Get-AzVM -Name $VmName -ResourceGroupName $ResourceGroupName
$ImageDefinition = Get-AzGalleryImageDefinition -ResourceId $ImageDefinitionResourceId
$SecurityType = ($ImageDefinition.Features | Where-Object {$_.Name -eq 'SecurityType'}).Value
If ($SecurityType -like '*Supported') {
    Write-Log -Message "SecurityType set to '$SecurityType', must generate managed image before capture." -Type 'INFO'
    $HyperVGeneration = $ImageDefinition.HyperVGeneration
    $ImageConfig = New-AzImageConfig -Location $Location -SourceVirtualMachineId $Vm.Id -HyperVGeneration $HyperVGeneration
    $Image = New-AzImage -Image $ImageConfig -ImageName "img-$VMName" -ResourceGroupName $ResourceGroupName
    $SourceId = $Image.Id
} Else {
    $SourceId = $Vm.Id
}

Disconnect-AzAccount | Out-Null

$Output = [pscustomobject][ordered]@{
    SourceId = $SourceId
}
$JsonOutput = $Output | ConvertTo-Json
return $JsonOutput
