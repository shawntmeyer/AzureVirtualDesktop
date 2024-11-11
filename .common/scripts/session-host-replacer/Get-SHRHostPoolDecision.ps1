function Get-SHRHostPoolDecision {
    <#
    .SYNOPSIS
        This function will decide how many session hosts to deploy and if we should decommission any session hosts.
    #>
    [CmdletBinding()]
    param (
        # Session hosts to consider
        [Parameter()]
        [array] $SessionHosts = @(),

        # Running deployments
        [Parameter()]
        $RunningDeployments,

        # Target age of session hosts in days - after this many days we consider a session host for replacement.
        [Parameter()]
        [int] $TargetVMAgeDays = (Get-FunctionConfig _TargetVMAgeDays),

        # Target number of session hosts in the host pool. If we have more than or equal to this number of session hosts we will decommission some.
        [Parameter()]
        [int] $TargetSessionHostCount = (Get-FunctionConfig _TargetSessionHostCount),

        [Parameter()]
        [int] $TargetSessionHostBuffer = (Get-FunctionConfig _TargetSessionHostBuffer),

        # Latest image version
        [Parameter()]
        [PSCustomObject] $LatestImageVersion,

        # Should we replace session hosts on new image version
        [Parameter()]
        [bool] $ReplaceSessionHostOnNewImageVersion = (Get-FunctionConfig _ReplaceSessionHostOnNewImageVersion),

        # Delay days before replacing session hosts on new image version
        [Parameter()]
        [int] $ReplaceSessionHostOnNewImageVersionDelayDays = (Get-FunctionConfig _ReplaceSessionHostOnNewImageVersionDelayDays)
    )
    # Basic Info
    Write-OutputDetailed "We have $($SessionHosts.Count) session hosts (included in Automation)"
    # Identify Session hosts that should be replaced
    if ($TargetVMAgeDays -gt 0) {
        $targetReplacementDate = (Get-Date).AddDays(-$TargetVMAgeDays)
        [array] $sessionHostsOldAge = $SessionHosts | Where-Object { $_.DeployTimestamp -lt $targetReplacementDate }
        Write-OutputDetailed "Found $($sessionHostsOldAge.Count) hosts to replace due to old age. $($($sessionHostsOldAge.VMName) -join ',')"

    }

    if ($ReplaceSessionHostOnNewImageVersion) {
        $latestImageAge = (New-TimeSpan -Start $LatestImageVersion.Date -End (Get-Date -AsUTC)).TotalDays
        Write-OutputDetailed "Latest Image $($LatestImageVersion.Version) is $latestImageAge days old."
        if ($latestImageAge -ge $ReplaceSessionHostOnNewImageVersionDelayDays) {
            Write-OutputDetailed "Latest Image age is older than (or equal) New Image Delay value $ReplaceSessionHostOnNewImageVersionDelayDays"
            [array] $sessionHostsOldVersion = $sessionHosts | Where-Object { $_.ImageVersion -ne $LatestImageVersion.Version }
            Write-OutputDetailed "Found $($sessionHostsOldVersion.Count) session hosts to replace due to new image version. $($($sessionHostsOldVersion.VMName) -Join ',')"
        }
    }

    [array] $sessionHostsToReplace = ($sessionHostsOldAge + $sessionHostsOldVersion) | Select-Object -Property * -Unique
    Write-OutputDetailed "Found $($sessionHostsToReplace.Count) session hosts to replace in total. $($($sessionHostsToReplace.VMName) -join ',')"

    # Good Session Hosts

    $goodSessionHosts = $SessionHosts | Where-Object { $_.VMName -notin $sessionHostsToReplace.VMName }
    $sessionHostsCurrentTotal = ([array]$goodSessionHosts.VMName + [array]$runningDeployments.SessionHostNames ) | Select-Object -Unique

    Write-OutputDetailed "We have $($sessionHostsCurrentTotal.Count) good session hosts including $($runningDeployments.SessionHostName.Count) session hosts being deployed"
    Write-OutputDetailed "We target having $TargetSessionHostCount session hosts in good shape"
    Write-OutputDetailed "We have a buffer of $TargetSessionHostBuffer session hosts more than the target."

    $weCanDeployUpTo = $TargetSessionHostCount + $TargetSessionHostBuffer - $SessionHosts.count - $RunningDeployments.SessionHostNames.Count
    if ($weCanDeployUpTo -ge 0) {
        Write-OutputDetailed "We can deploy up to $weCanDeployUpTo session hosts" 

        $weNeedToDeploy = $TargetSessionHostCount - $sessionHostsCurrentTotal.Count
        if ($weNeedToDeploy -gt 0) {
            Write-OutputDetailed "We need to deploy $weNeedToDeploy new session hosts"
            $weCanDeploy = if ($weNeedToDeploy -gt $weCanDeployUpTo) { $weCanDeployUpTo } else { $weNeedToDeploy } # If we need to deploy 10 machines, and we can deploy 5, we should only deploy 5.
            Write-OutputDetailed "Buffer allows deploying $weCanDeploy session hosts"
        }
        else {
            $weCanDeploy = 0
            Write-OutputDetailed "We have enough session hosts in good shape."
        }
    }
    else {
        Write-OutputDetailed "Buffer is full. We can not deploy more session hosts"
        $weCanDeploy = 0
    }


    $weCanDelete = $SessionHosts.Count - $TargetSessionHostCount
    if ($weCanDelete -gt 0) {
        Write-OutputDetailed "We need to delete $weCanDelete session hosts"
        if ($weCanDelete -gt $sessionHostsToReplace.Count) {
            Write-OutputDetailed "Host pool is over populated"

            $goodSessionHostsToDeleteCount = $weCanDelete - $sessionHostsToReplace.Count
            Write-OutputDetailed "We will delete $goodSessionHostsToDeleteCount good session hosts"

            $selectedGoodHostsTotDelete = [array] ($goodSessionHosts | Sort-Object -Property Session | Select-Object -First $goodSessionHostsToDeleteCount)
            Write-OutputDetailed "Selected the following good session hosts to delete: $($($selectedGoodHostsTotDelete.VMName) -join ',')"
        }
        else {
            $selectedGoodHostsTotDelete = @()
            Write-OutputDetailed "Host pool is not over populated"
        }

        $sessionHostsPendingDelete = ($sessionHostsToReplace + $selectedGoodHostsTotDelete) | Select-Object -First $weCanDelete
        Write-OutputDetailed "The following Session Hosts are now pending delete: $($($SessionHostsPendingDelete.VMName) -join ',')"

    }
    elseif ($sessionHostsToReplace.Count -gt 0) {
        Write-OutputDetailed "We need to delete $($sessionHostsToReplace.Count) session hosts but we don't have enough session hosts in the host pool."
    }
    else { Write-OutputDetailed "We do not need to delete any session hosts" }


    [PSCustomObject]@{
        PossibleDeploymentsCount       = $weCanDeploy
        PossibleSessionHostDeleteCount = $weCanDelete
        SessionHostsPendingDelete      = $sessionHostsPendingDelete
        ExistingSessionHostVMNames     = ([array]$SessionHosts.VMName + [array]$runningDeployments.SessionHostNames) | Select-Object -Unique
    }
}