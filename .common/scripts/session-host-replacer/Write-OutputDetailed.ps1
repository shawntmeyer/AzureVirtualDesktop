function Write-OutputDetailed 
    {
		[CmdletBinding()]
		param (
			[Parameter(Mandatory = $false)]
			[switch]$Err,

			[Parameter(Mandatory = $true, Position = 0)]
			[string]$Message,

			[Parameter(Mandatory = $false)]
			[switch]$Warn
		)

		[string]$MessageTimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
		$Message = "[$($MyInvocation.ScriptLineNumber)] $Message"
		[string]$WriteMessage = "[$($MessageTimeStamp)] $Message"

		if ($Err)
        {
			Write-Error $WriteMessage
			$Message = "ERROR: $Message"
		}
		elseif ($Warn)
        {
			Write-Warning $WriteMessage
			$Message = "WARN: $Message"
		}
		else 
        {
			Write-Output $WriteMessage
		}
	}