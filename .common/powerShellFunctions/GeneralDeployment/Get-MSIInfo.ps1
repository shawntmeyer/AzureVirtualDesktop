function Get-MsiInfo {
	<#
	.SYNOPSIS
	Queries parameter information from one or more MSI files

	.DESCRIPTION
	By default will return the ProductCode,ProductVersion,ProductName,Manufacturer,ProductLanguage,FullVersion.  If an empty string
	is provided for the Property parameter, then all properties are returned

	.PARAMETER Path
	MSI Path(s) provided either explicitly or from the pipeline

	.PARAMETER Property
	The names of the MSI properties to return.  Specify empty string to return all properties

	.EXAMPLE
	gci *.msi | Get-MsiInfo -Property 'ProductName','ProductVersion','Manufacturer'
	--------------------
	Gets specific properties for all MSIs in the current directory

	.EXAMPLE
	gci *.msi | Get-MsiInfo
	--------------------
	Get all properties for all MSIs in the current directory
	#>
		[CmdletBinding()]
		param(
			[parameter(Mandatory=$True, ValueFromPipeline=$true)]
			[IO.FileInfo[]]$Path,
			[AllowEmptyString()]
			[AllowNull()]
			[string[]]$Property
		)
	
		Begin {
			## Get the name of this function and write header
			[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
			Write-Verbose "${CmdletName}: Starting with [$PSBoundParameters]"
			$winInstaller = New-Object -ComObject WindowsInstaller.Installer
		}
		Process {
			try {
				Write-Verbose "${CmdletName}: Opening MSIFile: $Path"
				$msiDb = $winInstaller.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $winInstaller, @($Path.FullName, 0))
				if($Property) {
					Write-Verbose "${CmdletName}: Property: $Property specified"
					$propQuery = 'WHERE ' + (($Property | ForEach-Object { "Property = '$($_)'"}) -join ' OR ')
				}
				$query = ("SELECT Property,Value FROM Property {0}" -f ($propQuery))
	 
				$view = $msiDb.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $msiDb, ($query))
				$null = $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
	 
				$msiInfo = [PSCustomObject]@{'File' = $Path}
				do {
					$null = $view.GetType().InvokeMember('ColumnInfo', 'GetProperty', $null, $view, 0)
					$record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
					if(-not $record) { break; }
					$propName = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1) | select-object -First 1
					$value = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 2) | select-object -First 1
					$msiInfo = $msiInfo | Add-Member -MemberType NoteProperty -Name $propName -Value $value -PassThru
				} while ($true)
	 
				$null = $msiDb.GetType().InvokeMember('Commit', 'InvokeMethod', $null, $msiDb, $null)
				$null = $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
				Write-Verbose "${CmdletName}: Returning information about msi file."       
				$msiInfo
			}
			catch {
				Write-Error $_
				Write-Error $_.ScriptStackTrace
	 
			}
		}
		End {
			try {
				$null = [Runtime.Interopservices.Marshal]::ReleaseComObject($winInstaller)
				[GC]::Collect()
			} catch {
				Write-Error 'Failed to release Windows Installer COM reference'
				Write-Error $_
			}
			Write-Verbose "${CmdletName}: Exit"	 
		}
	}