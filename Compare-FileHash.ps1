#Requires -Version 3

<#
.SYNOPSIS
Compares the hashes of a list of files using various algorithms.

.DESCRIPTION
The Compare-FileHash cmdlet will compare the hash values of a list of files against each other, 
or an expected hash. Files are passed to the cmdlet using '-Files', separated by commas.
The cmdlet will use SHA512, or a list of specified algorithms, to perform the comparison.
It will return 'MATCH' if all hash values matched or 'MISMATCH' if one of the hash values did not match.

.PARAMETER Files
The list of file paths, separated by commas, from which to compare the hashes.
A minimum of two paths must be supplied (or one path, if '-Expected' is passed), however there is no upper limit.

.PARAMETER Algorithms
Determines which algorithm(s) are used to compute the specified files' hashes.
You may pass any number of supported algorithms, separated by commas.
Passing 'All' will run all algorithms.When unspecified, SHA512 will be used.

.PARAMETER Expected
Allows you to specify the hash you are expecting, and compares the file(s) against it,
rather than against each other. Passing this switch reduces the minimum '-Files' limit
from 2 to 1. '-Expected' cannot be passed with '-Algorithms'

.PARAMETER Quiet
Suppresses the individual hash values from being printed;
only the final result ('MATCH' or 'MISMATCH') will be printed.

.PARAMETER Fast
Returns 'MATCH' if the first computed algorithm's hashes match.
This skips the calculation and comparison of any subsequent algorithm's hashes.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt'

In this example, the cmdlet will compare the SHA512 hashes of file1.txt and file2.txt and 
print the hash values of each file along with the final comparison result.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt','C:\file3.txt' -Quiet

In this example, the cmdlet will compare the SHA512 hashes of file1.txt, file2.txt and file3.txt,
and only print the final comparison result ('MATCH' or 'MISMATCH') without any further verbosity.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt' -Fast -Algorithms All

In this example, the cmdlet will start comparing all algorithms' hashes of file1.txt and file2.txt and
will return 'MATCH' immediately if the first algorithm matches, skipping the rest of the algorithms.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt' -Algorithms SHA1,MD5,SHA384

In this example, the cmdlet will compare the SHA1, MD5, and SHA384 hashes of file1.txt and file2.txt.
If any of the hashes do not match, the rest of the algorithms will not be computed, and 'MISMATCH' will be printed.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt' -Expected DA39A3EE5E6B4B0D3255BFEF95601890AFD80709

In this example, the cmdlet will automatically detect that the input hash is SHA1, based on its length
(in this case, 40 characters), and compare file1.txt to that expected hash.
#>

function Compare-FileHash {
	[CmdletBinding()]
	param ( 
		[Parameter(Mandatory=$true)]
		[string[]]$Files,
		
		[Parameter(Mandatory=$false)]
		[ValidateSet("SHA512","SHA384","SHA256","SHA1","MD5","All")]
		[string[]]$Algorithms,

		[Parameter(Mandatory=$false)]
		[string]$Expected,

		[Parameter(Mandatory=$false)]
		[switch]$Quiet = $false,

		[Parameter(Mandatory=$false)]
		[switch]$Fast = $false
	)

	# Oneshot variable on script scope to ensure column headers of Get-FileHash table are only printed once
	$script:tableHeaders = $false

	# Warn and return if '-Expected' is passed with '-Algorithms'
	if ($Expected -and $Algorithms) {
		Write-Error "When '-Expected' is specified, '-Algorithms' must be omitted.`nThe algorithm of your expected hash will be automatically derived from its length."
		return
	}

	# If '-Algorithms' is unspecified, default to SHA512 (after ensuring '-Expected' + '-Algorithms' mutual exclusivity). Else, remove duplicate objects
	if (-not $Algorithms) { $Algorithms = "SHA512" } else { $Algorithms = $Algorithms | Select-Object -Unique }

	# Automatically derive algorithm of '-Expected' hash from its length
	if ($Expected) {

		$Algorithms = @()

		$Algorithms = switch ($Expected.Length) {
			32  { "MD5" }
			40  { "SHA1" }
			64  { "SHA256" }
			96  { "SHA384" }
			128 { "SHA512" }
			default {
				Write-Error "Invalid length of '-Expected' hash ($($Expected.Length) characters). Supported algorithms/lengths are as follows:`n`n"
				Write-Host -ForegroundColor Red "MD5 - 32`nSHA1 - 40`nSHA256 - 64`nSHA384 - 96`nSHA512 - 128"
				return
			}
		}
	}

	# If '-Algorithms' contains 'All', run all algorithms, else run what is specified
	$algsToRun = if ($Algorithms -contains "All") { "SHA512","SHA384","SHA256","SHA1","MD5" } else { $Algorithms }

	# Ensure at least two file paths have been provided, unless '-Expected' is passed
	if ($Files.Count -lt 2 -and -not $Expected) { Write-Error "When '-Expected' is not specified, at least two file paths must be provided for comparison." ; return }

	# Ensure supplied paths exist, and are files, not directories
	foreach ($path in $Files) {

		if (-not (Test-Path $path)) {
			$invalidPath = $true
			Write-Error "Invalid Path: $path"

		} elseif (-not (Test-Path $path -PathType Leaf)) {
			$invalidPath = $true
			Write-Error "Path is directory, not file: $path"
		}
	}

	# Allow all path issues to be printed prior to return
	if ($invalidPath) { return }

	# Add each file's path to its own hashtable within an array; its hashes from the algorithms specified will be stored here later
	foreach ($path in $Files) { [array]$table += @{ "Path" = $path } }

	function Get-Hashes {
		param (
			[Parameter(Mandatory=$true)]
			[string]$Type
		)

		# Compute hash for supplied algorithm, store result in relevant hashtable
		foreach ($number in 0..($Files.Count - 1)) {

			Write-Progress -Activity "Computing hash:" -Status "$($table[$number]["Path"]) | $Type"
			$table[$number][$Type] = Get-FileHash -Path $table[$number]["Path"] -Algorithm $Type

			# Only print table headers once, for the first hash
			if (-not $Quiet) {
				if (-not $tableHeaders) {
					$table[$number][$Type] | Out-Host
					$script:tableHeaders = $true

				} else { $table[$number][$Type] | Format-Table -HideTableHeaders | Out-Host }
			}
		}
	}

	function Compare-Hashes {
		param (
			[Parameter(Mandatory=$true)]
			[string]$Type
		)

		# Set item to compare to; if '-Expected' is passed, use it, else use first item
		$source = if ($Expected) { $Expected ; $i = 0 } else { $table[0][$Type].Hash ; $i = 1 }

		# Compare all items to $source, return $false if mismatch
		foreach ($item in $table[$i..($Files.Count - $i)]) {
			if ($source -ne $item[$Type].Hash) { return $false }
		}
		return $true
	}
 
	# Run Compare-Hashes with each algorithm
	foreach ($hashType in $algsToRun) {

		Get-Hashes -Type $hashType
		$match = Compare-Hashes -Type $hashType

		# If a mismatch is detected, or a match is detected and '-Fast' is specified, skip to results
		if (-not $match) { break } elseif ($Fast) { break }
	}

	# Print match results
	if ($match) {
		Write-Host -ForegroundColor Green "MATCH$(if ($Expected) { " EXPECTED" })"
	} else {
		Write-Host -ForegroundColor Red "MISMATCH$(if ($Expected) { ", expected $Expected" })"
	}
}
