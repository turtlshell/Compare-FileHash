#Requires -Version 5

<#
.SYNOPSIS
Compares the hash values of a list of files using multiple algorithms.

.DESCRIPTION
The Compare-FileHash function will compare the hash values of a list of files. The files are 
passed to the function as parameters. The function will use the SHA512, or a list of user-specified
algorithms, to perform the comparison. It will print the result of each hash comparison 
unless the -Quiet switch is passed. Finally, it will print either 'MATCH' if all hash 
values matched or 'MISMATCH' if one of the hash values did not match.

.PARAMETER Files
The list of file paths, separated by commas, to compare the hashes of. A minimum of two paths
must be supplied, however there is no maximum limit. This parameter is mandatory.

.PARAMETER Quiet
If passed, will suppress the individual hash values from being printed, 
and only the final result ('MATCH' or 'MISMATCH') will be printed.

.PARAMETER Quick
If passed, will print 'MATCH' if the first computed algorithm's hashes match.
This skips the calculation and comparison of any subsequent algorithm's hashes if they are not needed.

.PARAMETER Algorithm
If passed, will determine which algorithm(s) are used to compute the supplied files' hashes.
You may pass any number of algorithms, separated by commas, which the Get-FileHash cmdlet supports.
Passing "All" will run all algorithms, and if this parameter is not passed, it will default to SHA512.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt'

In this example, the function will compare the SHA512 hashes of file1.txt and file2.txt and 
print the hash values of each file along with the final comparison result.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt','C:\file3.txt' -Quiet

In this example, the function will compare the SHA512 hashes of file1.txt, file2.txt and file3.txt,
and only print the final comparison result ('MATCH' or 'MISMATCH') without any further verbosity.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt' -Quick

In this example, the function will compare the SHA512 hashes of file1.txt and file2.txt and
will return 'MATCH' immediately if the first algorithm matches, skipping the other algorithms.

.EXAMPLE
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt' -Algorithm SHA1,MD5,SHA384

In this example, the function will compare the SHA1, MD5, and SHA384 hashes of file1.txt and file2.txt.
If any of the hashes do not match, the rest of the algorithms will not be computed, and 'MISMATCH' will be printed.
#>

function Compare-FileHash {
	param ( 
		[Parameter(Mandatory=$true)]
		[string[]]$Files,
		
		[Parameter(Mandatory=$false)]
		[ValidateSet("SHA512","SHA384","SHA256","SHA1","MD5","All")]
		[string[]]$Algorithm = "SHA512",

		[Parameter(Mandatory=$false)]
		[switch]$Quiet = $false,

		[Parameter(Mandatory=$false)]
		[switch]$Quick = $false
	)

	# Oneshot variable on script scope to ensure column headers of Get-FileHash table are only printed once
	$script:tableHeaders = $false

	# Ensure at least two file paths have been provided
	if ($Files.Count -lt 2) { Write-Host -ForegroundColor Red "At least two file paths must be provided." ; break }

	# Add each file path to a hashtable so each algorithm's hash can be keyed and accessed flexibly
	foreach ($file in $Files) { [array]$table += @{ "Path" = $file } }

	# Ensure supplied paths exist, and are files, not directories
	foreach ($item in $table) {

		if (-not (Test-Path $item["Path"])) {
			$invalidPath = $true
			Write-Host -ForegroundColor Red "Invalid Path: $($item["Path"])"

		} elseif (-not (Test-Path $item["Path"] -PathType Leaf)) {
			$invalidPath = $true
			Write-Host -ForegroundColor Red "Path is directory, not file: $($item["Path"])"
		}
	}

	if ($invalidPath) { break }

	# If user selects 'All', use all algorithms. Else, split the algorithms string by commas and use those
	$algorithms = @("SHA512","SHA384","SHA256","SHA1","MD5")
	if ($Algorithm -notcontains "All") { $algorithms = $Algorithm.Split(",")}

	function Compare-Hashes {
		param ($alg)

		# Compute hash for supplied algorithm, store result in relevant hashtable
		foreach ($number in 0..($Files.Count-1)) {
			Write-Progress -Activity "Computing hash:" -Status "$($table[$number]["Path"]) | $alg"
			$table[$number][$alg] = Get-FileHash -Path $table[$number]["Path"] -Algorithm $alg

			# Only print table headers once, for the first hash
			if ((-not ($Quiet)) -and (-not ($tableHeaders))) {
				Write-Output $table[$number][$alg] | Out-Host
				$script:tableHeaders = $true

			} elseif (-not ($Quiet)) { Write-Output $table[$number][$alg] | Format-Table -HideTableHeaders | Out-Host }
		}
		# Compare results (all items to first item), return $true if mismatch
		foreach ($item in $table[1..($Files.Count-1)]) {
			if ($table[0][$alg].Hash -ne $item[$alg].Hash) { return $true }
		}
		return $false
	}

	# Run Compare-Hashes with each algorithm
	foreach ($alg in $algorithms) {
		$mismatch = Compare-Hashes -alg $alg
		# If a mismatch is detected, or a match is detected and '-Quick' is specified, skip to results
		if ($mismatch) { break } elseif ($Quick) { break }
	}
	# Print match results
	if ($mismatch) { Write-Host -ForegroundColor Red "MISMATCH"} else { Write-Host -ForegroundColor Green "MATCH" }
}
