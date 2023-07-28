#Requires -Version 3

<#
.SYNOPSIS
Compares the hashes of a list of files using various algorithms.

.DESCRIPTION
The Compare-FileHash cmdlet will compare the hash values of a list of files. The files are 
passed to the cmdlet as a parameter, separated by commas. The cmdlet will use SHA512,
or a list of user-specified algorithms, to perform the comparison. It will print the result
of each hash comparison unless the -Quiet switch is passed. Finally, it will return either
'MATCH' if all hash values matched or 'MISMATCH' if one of the hash values did not match.

.PARAMETER Files
The list of file paths, separated by commas, to compare the hashes of.
A minimum of two paths must be supplied, however there is no upper limit.

.PARAMETER Algorithms
Determines which algorithm(s) are used to compute the specified files' hashes.
You may pass any number of algorithms, separated by commas, which the Get-FileHash cmdlet supports.
Passing "All" will run all algorithms, and if this parameter is not passed, it will default to SHA512.

.PARAMETER Expected
Allows user to specify the hash they are expecting, and compares the file(s) against that,
rather than against each other. Passing this switch reduces the minimum '-Files' limit
from 2 to 1, and limits '-Algorithms' to 1 type.

.PARAMETER Quiet
Suppresses the individual hash values from being printed;
only the final result ('MATCH' or 'MISMATCH') will be printed.

.PARAMETER Fast
Returns 'MATCH' if the first computed algorithm's hashes match.
This skips the calculation and comparison of any subsequent algorithm's hashes if they are not needed.

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
will return 'MATCH' immediately if the first algorithm matches, skipping the other algorithms.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt' -Algorithms SHA1,MD5,SHA384

In this example, the cmdlet will compare the SHA1, MD5, and SHA384 hashes of file1.txt and file2.txt.
If any of the hashes do not match, the rest of the algorithms will not be computed, and 'MISMATCH' will be printed.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt' -Expected D41D8CD98F00B204E9800998ECF8427E

In this example, the cmdlet will automatically detect that the input hash is MD5, based on its length
(in this case, 32 characters), and compare file1.txt to that expected hash.
#>

function Compare-FileHash {
	[CmdletBinding()]
	param ( 
		[Parameter(Mandatory=$true)]
		[string[]]$Files,
		
		[Parameter(Mandatory=$false)]
		[ValidateSet("SHA512","SHA384","SHA256","SHA1","MD5","All")]
		[string[]]$Algorithms = "SHA512",

		[Parameter(Mandatory=$false)]
		[string]$Expected,

		[Parameter(Mandatory=$false)]
		[switch]$Quiet = $false,

		[Parameter(Mandatory=$false)]
		[switch]$Fast = $false
	)
	# Oneshot variable on script scope to ensure column headers of Get-FileHash table are only printed once
	$script:tableHeaders = $false

	# Lengths of each supported hash type, to validate length of hash passed with '-Expected'. No duplicate lengths allowed, would break '-Expected' algorithm detection.
	$hashLengths = @{ "MD5" = 32 ; "SHA1" = 40 ; "SHA256" = 64 ; "SHA384" = 96 ; "SHA512" = 128 }

	# Ensure at least two file paths have been provided
	if ($Files.Count -lt 2 -and -not ($Expected)) { Write-Error "When '-Expected' is not specified, at least two file paths must be provided." ; return }

	# Ensure supplied paths exist, and are files, not directories
	foreach ($file in $Files) {

		if (-not (Test-Path $file)) {
			$invalidPath = $true
			Write-Error "Invalid Path: $file"

		} elseif (-not (Test-Path $file -PathType Leaf)) {
			$invalidPath = $true
			Write-Error "Path is directory, not file: $file"
		}
	}

	# Allow all path issues to be printed prior to return
	if ($invalidPath) { return }

	# Automatically detect '-Expected' input hash type based on length
	if ($Expected) {

		$Algorithms = @()

		foreach ($key in $hashLengths.Keys) {
			if ($hashLengths[$key] -eq $Expected.Length) {
				$Algorithms = $key
				break
			}
		}
		if (-not ($Algorithms)) {
			Write-Error "Invalid length of '-Expected' hash ($($Expected.Length) characters). Supported hashes/lengths are as follows:`n`n"
			$hashLengths.Keys | Sort-Object | ForEach-Object { "$_ - $($hashLengths[$_])" } | Write-Host -ForegroundColor Red
			return
		}
	}

	# Add each file's path to a hashtable which contains the path and its hashes from specified algorithms
	foreach ($file in $Files) { [array]$table += @{ "Path" = $file } }

	# Ensure only 1 algorithm is selected for use when -Expected is specified
	if($Expected -and (($Algorithms.Count -gt 1) -or ($Algorithms -contains "All"))) {
		Write-Error "When '-Expected' is specified, '-Algorithm' is limited to one type."
		return
	}

	# If user's algorithm selection contains "All", run all algorithms, else just run what user specifies
	$algorithms = if ($Algorithms -contains "All") { @("SHA512","SHA384","SHA256","SHA1","MD5") } else { $Algorithms }

	function Get-Hashes {
		param (
			[Parameter(Mandatory=$true)]
			[string]$Type
		)

		# Compute hash for supplied algorithm, store result in relevant hashtable
		foreach ($number in 0..($Files.Count-1)) {

			Write-Progress -Activity "Computing hash:" -Status "$($table[$number]["Path"]) | $Type"
			$table[$number][$Type] = Get-FileHash -Path $table[$number]["Path"] -Algorithm $Type

			# Only print table headers once, for the first hash
			if ((-not ($Quiet)) -and (-not ($tableHeaders))) {
				$table[$number][$Type] | Out-Host
				$script:tableHeaders = $true

			} elseif (-not ($Quiet)) { $table[$number][$Type] | Format-Table -HideTableHeaders | Out-Host }
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
	foreach ($hashType in $algorithms) {

		Get-Hashes -Type $hashType
		$match = Compare-Hashes -Type $hashType

		# If a mismatch is detected, or a match is detected and '-Fast' is specified, skip to results
		if (-not ($match)) { break } elseif ($Fast) { break }
	}

	# Print match results
	if ($match) {
		Write-Host -ForegroundColor Green "MATCH$(if ($Expected) { " EXPECTED" })"
	} else {
		Write-Host -ForegroundColor Red "MISMATCH$(if ($Expected) { ", expected $Expected" })"
	}
}
