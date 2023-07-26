# Compare-FileHash

A native PowerShell function which can be used to compare the hash values of a list of files using various hashing algorithms. The function uses SHA512 as the default algorithm, but you can specify which algorithm(s) you want to use.

It prints the result of each hash for each file (unless the '-Quiet' switch is used), and if all algorithms' hash values match (or if one algorithm's values match, using the '-Quick' switch), it will print 'MATCH'. If any hash value does not match, it will print 'MISMATCH'.

## Table of Contents

- [Installation & Setup](#installation&setup)
- [Usage](#usage)
- [Parameters](#parameters)
- [Algorithms](#algorithms)
- [License](#license)
- [Contribution](#contribution)

## Installation & Setup

To clone and use this function, install & use Git. From PowerShell:

```
# Clone this repository
PS > git clone https://github.com/turtlshell/Compare-FileHash

# Extract the archive
PS > Expand-Archive Compare-FileHash.zip

# CD into the repository
PS > cd Compare-FileHash

# (Optional, depending on your security settings) Set Execution Policy
PS > Set-ExecutionPolicy Bypass -Scope Process

# Import the function
PS > . .\Compare-FileHash.ps1
```

## Usage

Here's how to use the Compare-FileHash function:

1. Import the function into your PowerShell session:
```
. .\Compare-FileHash.ps1
```

2. Use the function:

- Compare SHA512 hashes of two files:
```
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt'
```

- Compare SHA512 hashes of multiple files, suppressing individual hash results:
```
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt','C:\file3.txt' -Quiet
```

- Compare SHA512 hashes of two files, and return 'MATCH' on the first algorithm match, skipping subsequent algorithms:
```
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt' -Quick
```

- Compare the specified hashing algorithms of two files:
```
Compare-FileHash -Files 'C:\file1.txt','C:\file2.txt' -Algorithm SHA1,MD5,SHA384
```

## Parameters

#### -Files (mandatory)

The list of file paths, separated by commas, to compare the hashes of. A minimum of two paths must be supplied, however there is no maximum limit.

#### -Algorithm (optional)

If passed, will determine which algorithm(s) are used to compute the supplied files' hashes. You may pass any number of algorithms, separated by commas, which the Get-FileHash cmdlet supports. Passing "All" will run all algorithms, and if this parameter is not passed, it will default to SHA512.

#### -Quiet (optional)

If passed, will suppress the individual hash values from being printed, and only the final result ('MATCH' or 'MISMATCH') will be printed.

#### -Quick (optional)

If passed, will print 'MATCH' if the first computed algorithm's hashes match. This skips the calculation and comparison of any subsequent algorithm's hashes if they are not needed.

## Algorithms

Compare-FileHash supports all algorithms which are supported by the native cmdlet Get-FileHash. As of right now, those are:

- SHA512
- SHA384
- SHA256
- SHA1*
- MD5*

See Microsoft's help page on [Get-FileHash](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash?view=powershell-7.3#parameters) for more info.

\* Please note that these hashes are now considered insecure, and are vulnerable to certain attacks. If you're dealing with something sensitive or mission critical, use SHA256 or above.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Contribution

Contributions and issues are welcome. I may consider feature requests if I like your idea and I feel it has a strong use-case. Feel free to check [issues page](https://github.com/turtlshell/Compare-FileHash/issues) if you want to contribute.

## Show your support

Give a ⭐️ if you found this useful!

This readme was last updated on July 26, 2023.
