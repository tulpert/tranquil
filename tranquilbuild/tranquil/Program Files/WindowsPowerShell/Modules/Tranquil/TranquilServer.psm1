Function W {
  Param (
    $MSG,
    $LTX = "[NONE]"
  )
  Write-Host -ForegroundColor Cyan ($LTX + $MSG)
}
Function Update-TranquilRelease {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$BaseDirectory,
    [Parameter(Mandatory=$True)][String]$Section,
    [Parameter(Mandatory=$True)][String]$Distribution,
    [Parameter(Mandatory=$True)][String]$PackagesMD5,
    [Parameter(Mandatory=$True)][String]$PackagesSHA256,
    [Parameter(Mandatory=$True)][String]$PackagesGzMD5,
    [Parameter(Mandatory=$True)][String]$PackagesGzSHA256,
    [Parameter(Mandatory=$True)][String]$PackagesSize,
    [Parameter(Mandatory=$True)][String]$PackagesGzSize
  )

  $ltx          = '[UpdateRelease] '
  $privvars     = Get-PrivateVariables
  $TempDir      = $privvars['TMPDIR']

  # Create a temporary file to store the InRelease data in
  $_rand        = Get-Random -Minimum 1000000 -Maximum 9999999
  $_IRTemp      = $TempDir + '/' + $_rand

  # Find InRelease file based on the Section and BaseDirectory
  $_IRPath  = ($BaseDirectory.TrimEnd('/') + '/dists/' + $Distribution.TrimEnd('/') + '/' + 'InRelease')
  $_IRShort = ($_IRPath -Replace $BaseDirectory, "")
  
  Write-Verbose ($ltx + "Updating InRelease: " + $_IRShort)


  if ( Test-Path $_IRPath ) {
    # The InRelease file exists, so we can update it
    # First create a copy for us to manipulate
    Copy-Item -ErrorAction SilentlyContinue -Path $_IRPath -Destination $_IRTemp | Out-Null
    Write-Host -ForegroundColor Cyan (" --> Using TMP IR: " + $_IRTemp)
    $PackagesString   = $Section.TrimEnd('/') + '/' + 'Packages'
    $PackagesGzString = $PackagesString + '.gz'
W -ltx $ltx ("---> Working with ---> " + $PackagesString)
W -ltx $ltx ("---> Working with gx-> " + $PackagesGzString)
    if ( (Get-Content $_IRPath) -Match " [a-zA-Z0-9]{32}\s+.*${PackagesString}$") {
      (Get-Content $_IRTemp) -Replace "^ [a-zA-Z0-9]{32}\s+[0-9]+\s+${PackagesString}", (" " + ${PackagesMD5} + (" "*(24-($PackagesSize.Length))) + $PackagesSize + " " + $PackagesString) | Out-File -Encoding utf8 $_IRTemp
    } else {
      # Reset the _IRTemp file
      "" | Out-File -Encoding utf8 $_IRTemp
      # Now extract all the MD5 sums, sort them and put them back in while injecting the new Packages file
      # Because I am stubborn I want to sort by filename, but have the hash as the first element
      # Yes, all the next lines of code could be made easier if I sorted on the first element in the string
      # So, we extract all into a hash using the filename as a key and sort by that
      W -ltx $LTX ("Working on : " + $_IRTemp)
      Get-Content -ErrorAction SilentlyContinue $_IRPath | % {
        if ( $_ -Match "^[a-zA-Z0-9]+\:" ) {
          $_ | Out-File -Append -Encoding utf8 $_IRTemp
        }
W -ltx $LTX ("===> " + $_)
        if (( $_ -Match "^MD5Sum\:\s*$" ) -Or ($_ -Match "^SHA256\:\s*$")) {
          # Now run through the scenarios of: Packages MD5 and SHA256, Packages.gz MD5 and SHA256
          $q = @("MD5", "MD5gz", "SHA256", "SHA256gz")
          ForEach ( $i in $q) {
            W -ltx $LTX ("=== STARTING ===> ${i} ")


            if ($i -Match "^MD5") {
              $starter = "^MD5Sum\:\s*$"
              $filter  = "^ [a-z0-9]{32} "
            } elseif ($i -Match "^SHA256") {
              $starter = "^SHA256\:\s*$"
              $filter  = "^ [a-z0-9]{64} "
            }


            if ($i -Match ("gz$")) {
              $PackagesName   = "Packages.gz"
              $PackagesFile = $PackagesGzString
              $PSize        = $PackagesGzSize
              if ($i -Match "^md5") {
                $PackagesHash = $PackagesGzMD5
              } else {
                $PackagesHash = $PackagesGzSHA256
              }
            } else {
              $PackagesName   = "Packages"
              $PackagesFile   = $PackagesString
              $PSize          = $PackagesSize
              if ($i -Match "^md5") {
                $PackagesHash = $PackagesMD5
              } else {
                $PackagesHash = $PackagesSHA256
              }
            }

W -ltx $ltx ("Running with PackagesFile: " + $PackagesFile)
            if ( $_ -Match "${starter}") {
              # Start adding the Checksum
              $_ThisHash = @{}
              # And since we havent seen this package before, we can inject that as the first element
              if ( -Not $_ThisHash.ContainsKey($PackagesFile)) {
                $_ThisHash.Add($PackagesFile, " ${PackagesHash}" + (" "*(24-($PSize.Length))) + $PSize + " " + $PackagesFile)
              }
              $_ThisHash.Keys | % {
                $MyKey = ($_ -Replace "\s+", " ").trim().split(" ")[2..999] | Join-String -Separator "_"
                if ( $MyKey.Length -gt 0) {
W -ltx $ltx (" ------->>> FOUND Kay: " + $MyKey)
                  if ( -Not $_ThisHash.ContainsKey($MyKey)) {
W -ltx $ltx (" ------->>> FOUND STUFF <<-----")
                    $_ThisHash.Add($MyKey, $_)
                  }
                  W -ltx $LTX ("Using Key: " + $MyKey)
                }              
              }
              foreach ( $hashitem in $_ThisHash.Keys | Sort-Object ) {
                W -ltx $LTX ("Printing Hash line (${i}:${hashitem}): " + $_ThisHash[$hashitem])
                $_ThisHash[$hashitem] | Out-File -Append -Encoding utf8 $_IRTemp
              }
            }
          }
        }
      }
    }



        # if ( $_ -Match "^MD5Sum") {
        #   $_ | Out-File -Append -Encoding utf8 $_IRTemp
        #   # Start adding the MD5SUMS
        #   $MD5Hash = @{}
        #   W -ltx $ltx (" ${PackagesMD5}" + (" "*(24-($PackagesSize.Length))) + $PackagesSize + " " + $PackagesString)
        #   $MD5Sums    = (Get-Content -ErrorAction SilentlyContinue $_IRPath ) -Match "^ [a-z0-9]{32} " 
        #   # And since we havent seen this package before, we can inject that as the first element
        #   $MD5Hash.Add($PackagesString, " ${PackagesMD5}" + (" "*(24-($PackagesSize.Length))) + $PackagesSize + " " + $PackagesString)
        #   $MD5Sums | % {
        #       $MyKey = ($_ -Replace "\s+", " ").trim().split(" ")[2..999] | Join-String -Separator "_"
        #       $MD5Hash.Add($MyKey, $_)
        #       W -ltx $LTX ("Using Key: " + $MyKey)
        #   }
        #   foreach ( $hashitem in $MD5Hash.Keys | Sort-Object ) {
        #     W -ltx $LTX ("Printing MD5 line: " + $MD5Hash[$hashitem])
        #     $MD5Hash[$hashitem] | Out-File -Append -Encoding utf8 $_IRTemp
        #   }
        # }
        # # Now repeat for SHA256 for good measure
        # $SHA256Sums = (Get-Content -ErrorAction SilentlyContinue $_IRPath ) -Match "^ [a-z0-9]{64} " 
        # if ( $_ -Match "^SHA256") {
        #   $_ | Out-File -Append -Encoding utf8 $_IRTemp
        #   # Start adding the SHA256
        #   $SHA256Hash = @{}
        #   W -ltx $ltx (" ${PackagesSHA256}" + (" "*(24-($PackagesSize.Length))) + $PackagesSize + " " + $PackagesString)
        #   $SHA256Sums    = (Get-Content -ErrorAction SilentlyContinue $_IRPath ) -Match "^ [a-z0-9]{64} " 
        #   # And since we havent seen this package before, we can inject that as the first element
        #   $SHA256Hash.Add($PackagesString, " ${PackagesSHA256}" + (" "*(24-($PackagesSize.Length))) + $PackagesSize + " " + $PackagesString)
        #   $SHA256Sums | % {
        #       $MyKey = ($_ -Replace "\s+", " ").trim().split(" ")[2..999] | Join-String -Separator "_"
        #       $SHA256Hash.Add($MyKey, $_)
        #       W -ltx $LTX ("Using Key: " + $MyKey)
        #   }
    
        #   foreach ( $hashitem in $SHA256Hash.Keys | Sort-Object ) {
        #     W -ltx $LTX ("Printing SHA256 line: " + $SHA256Hash[$hashitem])
        #     $SHA256Hash[$hashitem] | Out-File -Append -Encoding utf8 $_IRTemp
        #   }
        # }
    # # Rinse and repeat for the .gz files. I should probably make this into a repeatable function, but not tonight
    # if ( (Get-Content $_IRPath) -Match " [a-zA-Z0-9]{32}\s+.*${PackagesGzString}$") {
    #   (Get-Content $_IRTemp) -Replace "^ [a-zA-Z0-9]{32}\s+[0-9]+\s+${PackagesGzString}", (" " + ${PackagesGzMD5} + (" "*(24-($PackageGzSize.Length))) + $PackageGzSize + " " + $PackagesGzString) | Out-File -Encoding utf8 $_IRTemp
    # } else {
    #   # Now extract all the MD5 sums, sort them and put them back in while injecting the new Packages file
    #   # Because I am stubborn I want to sort by filename, but have the hash as the first element
    #   # Yes, all the next lines of code could be made easier if I sorted on the first element in the string
    #   # So, we extract all into a hash using the filename as a key and sort by that
    #   W -ltx $LTX ("Working on : " + $_IRTemp)
    #   Get-Content -ErrorAction SilentlyContinue $_IRPath | % {
    #     if ( $_ -Match "^[a-zA-Z]+\:" ) {
    #       $_ | Out-File -Append -Encoding utf8 $_IRTemp
    #     }
    #     if ( $_ -Match "^MD5Sum") {
    #       $_ | Out-File -Append -Encoding utf8 $_IRTemp
    #       # Start adding the MD5SUMS
    #       $MD5Hash = @{}
    #       W -ltx $ltx (" ${PackagesGzMD5}" + (" "*(24-($PackageGzSize.Length))) + $PackageGzSize + " " + $PackagesGzString)
    #       $MD5Sums    = (Get-Content -ErrorAction SilentlyContinue $_IRPath ) -Match "^ [a-z0-9]{32} " 
    #       # And since we havent seen this package before, we can inject that as the first element
    #       $MD5Hash.Add($PackagesGzString, " ${PackagesGzMD5}" + (" "*(24-($PackageGzSize.Length))) + $PackageGzSize + " " + $PackagesGzString)
    #       $MD5Sums | % {
    #           $MyKey = ($_ -Replace "\s+", " ").trim().split(" ")[2..999] | Join-String -Separator "_"
    #           $MD5Hash.Add($MyKey, $_)
    #           W -ltx $LTX ("Using Key: " + $MyKey)
    #       }
    #       foreach ( $hashitem in $MD5Hash.Keys | Sort-Object ) {
    #         W -ltx $LTX ("Printing MD5 line: " + $MD5Hash[$hashitem])
    #         $MD5Hash[$hashitem] | Out-File -Append -Encoding utf8 $_IRTemp
    #       }
    #     }
    #     # Now repeat for SHA256 for good measure
    #     $SHA256Sums = (Get-Content -ErrorAction SilentlyContinue $_IRPath ) -Match "^ [a-z0-9]{64} " 
    #     if ( $_ -Match "^SHA256") {
    #       $_ | Out-File -Append -Encoding utf8 $_IRTemp
    #       # Start adding the SHA256
    #       $SHA256Hash = @{}
    #       W -ltx $ltx (" ${PackagesGzSize}" + (" "*(24-($PackageGzSize.Length))) + $PackageGzSize + " " + $PackagesGzString)
    #       $SHA256Sums    = (Get-Content -ErrorAction SilentlyContinue $_IRPath ) -Match "^ [a-z0-9]{64} " 
    #       # And since we havent seen this package before, we can inject that as the first element
    #       $SHA256Hash.Add($PackagesGzString, " ${PackagesGzSize}" + (" "*(24-($PackageGzSize.Length))) + $PackageGzSize + " " + $PackagesGzString)
    #       $SHA256Sums | % {
    #           $MyKey = ($_ -Replace "\s+", " ").trim().split(" ")[2..999] | Join-String -Separator "_"
    #           $SHA256Hash.Add($MyKey, $_)
    #           W -ltx $LTX ("Using Key: " + $MyKey)
    #       }
    # 
    #       foreach ( $hashitem in $SHA256Hash.Keys | Sort-Object ) {
    #         W -ltx $LTX ("Printing SHA256 line: " + $SHA256Hash[$hashitem])
    #         $SHA256Hash[$hashitem] | Out-File -Append -Encoding utf8 $_IRTemp
    #       }
    #     }
    #   }
    # }
    if ( Test-Path $_IRTemp ) {
      Write-Verbose ("Updating InRelease file: " + $_IRPath )
      Move-Item -Force $_IRTemp $_IRPath
    }
    Write-Host -ForegroundColor Cyan (" --> Looking for package file : " + $PackagesGzString)
    Write-Host -ForegroundColor Cyan (" --> Looking for package file : " + $PackagesGzString)
  } else {
    Write-Host -ForegroundColor Red ($ltx + "[ERROR] Detected corrupt repository directory for [${BaseDirectory}] in distribution [${Distribution}]")
    Write-Host -ForegroundColor Red ($ltx + "[ERROR] Solve the issue or re-build the repository using Build-TranquilServer")
    Write-Error ("Error 169. Cannot continue")
    Break
  }
  New-Item -ErrorAction SilentlyContinue -ItemType Directory $_dest | Out-Null
}


<#
 .Synopsis
  Will setup and configure a Tranquil repository server

 .Description
  Will setup and configure a Tranquil repository server

 .Example
  Build-TranquilServer -Directory /path/to/directory -Version <serverversion>
  
  # Proper example to create a Windows 2016 repo server in an apache web directory on a Linux server
  Build-TranquilServer -Directory /var/www/html/tranquil/windows -Version win2016
  
 .Parameter BaseDirectory
  Path to the root directory that should contain packages and metadata for the repository. Normally the real life directory of the path referenced in your .list file

 .Parameter Distribution
  A string to denote the version, i.e. "win2016", "win2019" or "win2019_core". It could be anything you wish but will be referenced verbatim in users .list file

 .Parameter Description
  Describes this repository

 .Parameter Verbose
  Prints out Verbose information during run

 .Parameter Force
  Forces the install even if errors have been detected or access rights (run as Administrator) are not in place
#>
Function Build-TranquilServer {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$BaseDirectory,
    [Parameter(Mandatory=$True)][String]$Distribution,
    [String]$Description,
    [Switch]$WhatIf
  )

  $ltx = '[BuildServer] '

  # Check the variables that no crazy characters are input
  if ( $Distribution -iNotMatch "^[a-z0-9]*$") {
    Write-Warning ("Distribution must only contain alphanumeric characters (in lowercase)")
    return $False
  }

  # First ensure that all directories exist 
  $BaseDir  = $BaseDirectory -Replace "[\/]*$", ''
  $DistsDir = $BaseDir + '/dists/' + $Distribution
  $PoolDir  = $BaseDir + '/pool/'
  $_dirs     = @( $DistsDir, $PoolDir )

  $_dirs | Foreach-Object {
    if ($WhatIf) {
      Write-Host -ForegroundColor DarkYellow ("[WhatIf] Want to create directory: " + $_)
    } else {
      Write-Verbose ($ltx + "Ensure directory exists: " + $_)
      $tmp = New-Item -ErrorAction SilentlyContinue -Force -ItemType Directory $_
    }
    if ( Test-Path -PathType Container $_ ) { 
      Write-Host ("Directory is available: " + $_)
    } else {
      Write-Warning ($ltx + "Failed to create subdirectories. Please ensure directory exists and is writable ...")
      return $False
    }
  }

  # Now create the initial Release file
  $ReleaseFile = $DistsDir + '/InRelease'  
  $ReleaseContents = @{
    'Origin'        = "XXX"
    'Label'         = "xXx"
    'Suite'         = "UuU"
    'Version'       = "VvV"
    'Date'          = (Get-Date -UFormat "%Y-%m%-%d %T %Z")
    'Distribution'  = $Distribution
    'Architectures' = "aAa"
    'Components'    = "cCCc"
    'Description'   = $Description
  }
  if ( ! $WhatIf ) {
    # Only create a new InRelease file if it doesn't already exist
    if ( ! (Test-Path -PathType Leaf $ReleaseFile )) {
      Write-Verbose ($ltx + "Creating initial release file: " + $ReleaseFile)
      "" | Out-File -Append -Encoding utf8 -FilePath $ReleaseFile
      $ReleaseContents.Keys | % {
        ($_.Trim() + ": " + $ReleaseContents[$_].Trim() ) | Out-File -Append -Encoding utf8 -FilePath $ReleaseFile
      }
      # Add the placeholders for the Checksums
      "MD5Sum:" | Out-File -Append -Encoding utf8 -FilePath $ReleaseFile
      "SHA256:" | Out-File -Append -Encoding utf8 -FilePath $ReleaseFile
    }
  }
  Write-Host -ForegroundColor Green (" Releasefile ---> " + $ReleaseFile)
  Write-Host -ForegroundColor RED ($lpx+"THIS FUNCTION IS NOT FINISHED!")
}
  
<#
 .Synopsis
  Will add a created Tranquil package file to the repository

 .Description
  Will read the meta-data from a package fail and the contents to update the Tranquil server
  to allow for download and consumption of the package. If the Tranquil server has capability for GPG Signing
  it will do so.

 .Example
  Add-TranquilServerPackage -Package /path/to/package -BaseDirectory /path/to/server/files -Distribution win2019
  
 .Parameter Package
  Path to the package to add. The package will be read and imported into the correct Tranquil server directory path
  based on the metedata contained within the package (i.e. what the "TRANQUIL/control" file instructs. 

 .Parameter BaseDirectory
  The directory where the Tranquil server packages are stored

 .Parameter Distribution
  Which distribution is this repo for? i.e. win2019, win2016_core etc. 

 .Parameter NumVersions
  How many version of the same package should we keep. Default is q (i.e. latest).
  If set to 0, then will keep ALL versions.
  Legacy versions can be cleaned with Clean-TranquilServerPackage

 .Parameter Verbose
  Prints out Verbose information during run

 .Parameter Force
  Overwrite the Server package even if the package already exists
#>
Function Add-TranquilServerPackage {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$Package,
    [Parameter(Mandatory=$True)][String]$Distribution,
    [Parameter(Mandatory=$True)][String]$BaseDirectory,
    [String]$NumVersions = 1,
    [String]$Description,
    [Switch]$WhatIf
  )

  $privvars       = Get-PrivateVariables
  $TempDir        = $privvars['TMPDIR']
  $lpx            = '[PackageInfo] '
  
  # Check that the basedirectory actually exists
  if ( -Not (Test-Path $BaseDirectory) ) {
    Write-Error ("BaseDirectory does not exist ...")
    exit (668)
  }

  # Check that the package file actually exists 
  if ( -Not (Test-Path $Package) ) {
    Write-Error ("Package does not exist")
    Break 8124
  }

  $File = $Package
# write-host -ForegroundColor Cyan ("---> 1 <---")
# write-host -ForegroundColor Cyan ("---> 2 <---")
  if ( -Not ( Get-ChildItem -ErrorAction SilentlyContinue $File ) ) {  
    return $False
  }

  # Tests completed. Let's continue
  $_rand = Get-Random -Minimum 10000 -Maximum 99999
  $_dest = $TempDir + '/' + $_rand
  New-Item -ErrorAction SilentlyContinue -ItemType Directory $_dest | Out-Null

  Expand-Archive -Force -Verbose:$False -Path $File -DestinationPath $_dest | Out-Null
# write-host -ForegroundColor Cyan $_dest

  # Now check if there is a control file present
  # write-host -ForegroundColor Cyan ($_dest + '/' + $privvars['TRANQUILBUILD'] + '/control' )
  $_control = ($_dest + '/' + $privvars['TRANQUILBUILD'] + '/control' )

  # Check if Control file exists and returns any content
  Write-Verbose ( $ltx + "Checking content of control file: " + $_control)
  $_controlcontent = Get-Content $_control
 # write-host -ForegroundColor Cyan ("This: " + $_controlcontent)
  if ( -Not $_controlcontent ) {
    Write-Error ($ltx + "Package is not a valid Tranquil file.")
    exit (667)
  }
  # Write-Host -ForegroundColor Cyan ($_controlcontent)
  # Read the package metadata and find distribution packagename and version
  # to determine where to store the package meta content
  # Also check if all relevant metadata exists. We MUST have
  # * Package name  (package: <packagename>)
  # * Version       (version: 1.2.3)
  # 
  # The rest can be dedused or rely on defaults if not set
  #
  $FoundSection = $False
  
  $NewPackageHash = @{}
  $_controlcontent | sort | % {
    # Here we can add tests to verify that only approved content metadata is added. TODO
          # $thisPackage.Add($mySplit[0].ToLower(), $mySplit[1].ToLower())
    if (( $_ -NotMatch "^\s*[\#\-]" ) -And ( $_ -Match "\:")) {
      $mySplit = $_.Split(":")
      # In case the content metadata contains any ';' characters, this split will remove it. 
      # So we have to put it back
      $_value = ""
      $c = 1
      $m = $mySplit.Count
      while ($c -lt $m) {
        $_value += $mySplit[$c]
        if (  $c -ne ( ${m}-1 )) {
          $_value += ":"
        }
        $c += 1
      }
      # Write-Host -ForegroundColor Red $mySplit[0]
      # Write-Host -ForegroundColor Red $_value
      # Write-Host -ForegroundColor Red ("----")
    $NewPackageHash.Add($mySplit[0], $_value)
# write-Host -ForegroundColor Cyan ("   ---> Adding item: " + $mySplit[0] + "::" + $_value)
    }
    # $NewPackageMetadata += $_
    if ( $_ -Match "^Section\:" ) {
      $TmpSection = ($_ -Replace "^Section\:\s*", "").Trim()
      $FoundSection = $True
    }
  }

  # $BaseDistributionPath = (($BaseDirectory -Replace "[\/]*\s*$", "") + '/' + ($Distribution -Replace "[\/]*\s*$", "" ))
  $BaseDistributionPath = $BaseDirectory.TrimEnd('/') + '/dists/' + $Distribution.TrimEnd('/')
  if ( $FoundSection ) {
    $SectionPath = ($BaseDistributionPath + '/' + $TmpSection)
  } else {
    $SectionPath = ($BaseDistributionPath + '/' + 'main')
    $NewPackageHash.Add("Section", "main")
  }
  $ThisSection = $NewPackageHash["Section"]
# write-host -ForegroundColor Cyan ("Sectionpath: " + $SectionPath)

  # Now check if the new Package contains enought metadata to create a key
  if ( $NewPackageHash.ContainsKey("Package") -And $NewPackageHash.ContainsKey("Version")) {
    $NewPackageKey = ($NewPackageHash["Package"].Trim()+"-"+$NewPackageHash["Version"].Trim())
  } else {
    Write-Warning ( $ltx + "Could not locate new package name or version. Cant add package to repository ...")
    Return $False
  }

  # Write-Host -ForegroundColor Cyan ("TH2is: " + $NewPackageMetadata)
  Write-Verbose ( $ltx + "Using SectionPath: " + $SectionPath )
  Write-Verbose ( $ltx + "Importing new package: " + $NewPackageKey )

  # Reading contents of Package.gz file (if exists for this section).
  # if not exists, create a new Package.gz file
  $_packagedest = $TempDir      + '/_Packages_' + $_rand
  $_ptmpfilegz  = $_packagedest + '/' + 'Packages.gz'
  $_ptmpfile    = $_packagedest + '/' + 'Packages'
  $_packagegz   = $SectionPath  + '/' + 'Packages.gz'
  $_packagefile = $SectionPath  + '/' + 'Packages'
  Write-Verbose ( $ltx + 'Using PckTmp: ' + $_packagedest )
  Write-Verbose ( $ltx + 'Working on Packages.gz: ' + $_packagegz)
 # Write-Host -ForegroundColor Cyan ("---> Section :: ${SectionPath}")

  # Create a new section if it does not exist
  if ( ! ( Test-Path $SectionPath )) {
    try {
      New-Item -ItemType Directory $SectionPath | Out-Null
    } catch {
      Write-Error ("Could not create directory. Error 1515")
    }
  }

  # Create a new temp directory for the Package file
  if ( ! ( Test-Path $_packagedest )) {
    try {
      New-Item -ItemType Directory $_packagedest | Out-Null
    } catch {
      Write-Error ("Could not create directory. Error 1516")
    }
  }

  $_myCheck = Get-Item -ErrorAction SilentlyContinue $_packagegz
  # if ( (Test-Path $_packagegz) ) {
  if ( ($_myCheck.Exists) -And ( -Not $_myCheck.IsPsContainer) ) {
    Expand-Archive -ErrorAction SilentlyContinue -DestinationPath $_packagedest $_packagegz | Out-Null
  } 
  $PackageContents = Get-Content -ErrorAction SilentlyContinue $_ptmpfile
  # Reset the Package file
  # ("# Updated " + (Get-Date -UFormat "%Y-%m%-%d %H:%M:%S")) | Out-File -Encoding utf8 $_ptmpfile
  ("# Imported packages" )                                  | Out-File -Encoding utf8 $_ptmpfile
  ("#")                                                     | Out-File -Append -Encoding utf8 $_ptmpfile
  ("")                                                      | Out-File -Append -Encoding utf8 $_ptmpfile

# Write-Host -ForegroundColor Cyan ("000> " + $PackageContents )

  # We will now read the contents of the Package.gz file for the newly added package's Section
  # If the package does not already exist, add it to Package
  # If the package already exists, check for changes and add it to the Package
  # We also want the Package file to be alphabetical by Package, Version
  # (This is where we check how many versions of the same package we will allow to retain) - Maybe...?

  # We will read continously through the package. Any blank line(s) deliniates the different packages
  # Add the packages to a HASH so we can sort it and inject it back
  $NewPackage = $True
  $NewPackageContents = @{}
  $DoneRegisteredNewPackage = $False
  $PackageContents | % {
    # Write-Host -ForegroundColor Cyan ("Packagecontetnline: " + $_)
    if ( $NewPackage ) {
      # Write-Host -ForegroundColor Cyan ("---> This is a new package <----")
      $NewPackage = $False
      if ( $thisPackage.count -gt 0 ) {
        # We have found a package. Store it in our hash using Name+Version as a key
        $thisKey = (($thisPackage.Package).ToLower().Trim() +'-'+ ($thisPackage.Version).ToLower().Trim())
        # Write-Host -ForegroundColor Cyan ("PLANTER: " + $thisKey)
        # Try to inject the new package metadata in alphabetical order
        if ( $NewPackageKey -lt $thisKey ) {
          # write-host -ForegroundColor Cyan ("MMMM> " + $thisKey + " - " + $NewPackageKey)
          # Check if the package is not already registered
          if ( -Not ($NewPackageContents.ContainsKey($NewPackageKey)) ) {
            $NewPackageContents.Add( $NewPackageKey, $NewPackageHash )
            $DoneRegisteredNewPackage = $True
          }
        }
        if ( -Not ($NewPackageContents.ContainsKey($thisKey)) ) {
          Write-Verbose ( $ltx + "Adding package ["+$thisKey+"] to repository ...")
          $NewPackageContents.Add( $thisKey, $thisPackage )
        } else {
          Write-Verbose ( $ltx + "Package ["+$thisKey+"] already exists in repository ...")
        }
      }
      $thisPackage = @{}
    }
    if ( $_ -Match "^\s*$" ) {
      $NewPackage = $True
    } else {
# Write-Host -ForegroundColor Cyan ("PKLine: " + $_)
      if ($_ -NotMatch "^\s*[\#\-]" ) {
        if ( $_ -Match "^[A-Z][a-z]*\:" ) {
          $mySplit = $_.Split(":")
          $thisPackage.Add($mySplit[0].ToLower(), $mySplit[1].ToLower())
# Write-Host -ForegroundColor Cyan ("   LLLLLL> " + $mySplit[0].ToLower() + "::" + $mySplit[1].ToLower())
        }
      }
    }
  }

  # If this is the first package in the section, we must treat it specifically
  if ( -Not $DoneRegisteredNewPackage ) {
    if ( -Not ($NewPackageContents.ContainsKey($NewPackageKey)) ) {
      $NewPackageContents.Add( $NewPackageKey, $NewPackageHash )
    }
  }


  # Now start the output of a package
  # write-host -ForegroundColor Cyan ("This is the NEW contents: " + $NewPackageContents )
  foreach($itemkey in $NewPackageContents.GetEnumerator() | Sort-Object Name ) {
    $NewOutput = ""
    # Write-Host -ForegroundColor Cyan ("ItemKey: " + $itemkey.Name)
    foreach ( $packageitem in $NewPackageContents[$itemkey.Name] | Sort-Object Name ) {
      foreach ( $packagekey in $packageitem.keys | Sort-Object  ) {
        ($packagekey.Trim() + ": " + $packageitem[$packagekey].Trim()) | Out-File -Append -Encoding utf8 -FilePath $_ptmpfile
      }
      # Add a newline to deliniate the packages
      "" | Out-File -Append -Encoding utf8 -FilePath $_ptmpfile 
    }
  }

  # Add stop info to package
  "--- End of Package ---" |  Out-File -Append -Encoding utf8 -FilePath $_ptmpfile

  # Take a MD5SUM of the package and register it in the InRelease file for checksum
  # This checksum should be similar across Tranquil Server clusters
  $PackagesMD5  = (Get-FileHash -Algorithm md5 ${_ptmpfile}).Hash
  $PackagesSize = (Get-Item $_ptmpfile).Length
  Write-Verbose ("Checksum of Package is now: " + $PackagesMD5)
  Compress-Archive -DestinationPath $_ptmpfilegz $_ptmpfile | Out-Null

  # Check that the new archive file has been created and move it into its final location
  $_myCheck = Get-Item -ErrorAction SilentlyContinue $_ptmpfilegz
  if ( ($_myCheck.Exists) -And ( -Not $_myCheck.IsPsContainer) ) {
    # Write-Host -ForegroundColor Cyan ("Moving from "+ $_ptmpfilegz+" TO " + $_packagegz )
    # Take a MD5SUM of the compressed package and register it in the InRelease file for checksum
    # This checksum will differ across Tranquil Server clusters due to compressing algorithm
    $PackagesGzMD5    = (Get-FileHash -Algorithm md5    ${_ptmpfilegz}).Hash
    $PackagesGzSHA256 = (Get-FileHash -Algorithm SHA256 ${_ptmpfilegz}).Hash
    $PackagesGzSize  = (Get-Item $_ptmpfilegz).Length
    Write-Verbose ("Checksum of Package.gz is now: " + $PackagesGzMD5)
    Update-TranquilRelease -BaseDirectory $BaseDirectory -Section $ThisSection -PackagesMD5 $PackagesMD5 -PackagesSHA256 (Get-FileHash -Algorithm sha256 $_ptmpfile).Hash -PackagesGzMD5 $PackagesGzMD5 -PackagesGzSHA256 $PackagesGzSHA256    -PackagesSize $PackagesSize  -PackagesGzSize $PackagesGzSize -Distribution $Distribution
    Move-Item -Force $_ptmpfilegz $_packagegz
  }

  # Cleaning up Package file temp directory
  if ( Get-Item -ErrorAction SilentlyContinue $_packagedest ) {
    # Write-Host   -ForegroundColor Cyan ("Deleting : " +  $_packagedest )
    Write-Verbose ($ltx + "Removing tmp file: " + $_packagedest)
  }
  # Cleaning up main tmp directory
  if ( Get-Item -ErrorAction SilentlyContinue $_dest ) {
    # Write-Host   -ForegroundColor Cyan ("Deleting : " +  $_dest )
    Write-Verbose ($ltx + "Removing tmp file: " + $_dest)
  }
  
  # Write-Host -ForegroundColor Cyan "Schnarf"
}

Function Get-PrivateVariables {
  # Check if the tmp variable exists
  if ( Test-Path '/windows/temp' ) {
    $_TD = '/windows/temp'
  } elseif ( Test-Path '/temp' ) {
    $_TD = '/temp'
  } elseif ( Test-Path '/tmp' ) {
    $_TD = '/tmp'
  } else {
    Write-Error ("Could not detect any suitable temp directory. Cannot continue")
    exit (666)
  }
  $ProgramData        = '/programdata/tranquil'
  Return @{
    "TRANQUILBUILD"   = "TRANQUIL"
    "PKGEXTENSION"    = ".tp"
    "DEFAULTCOMPRESS" = ".zip"
    "RUNID"           = Get-Random(99999999)
    "TMPDIR"          = $_TD
    "CACHE"           = "${ProgramData}/cache"
    "LISTSDIR"        = "${ProgramData}/lists"
    "STATEFILE"       = "${ProgramData}/statefile"
    "SOURCESDIR"      = "${ProgramData}/sources"
    "METAKEY"         = "__tranquilmeta__"
    "SCRIPTEXT"       = @(".txt", ".ps1", ".tp", , ".py", ".tpam", "")   # Not sure i will use this one
    "SOURCEDIRS"      = @("${ProgramData}/sources", '/etc/tranquil/sources', '~/.tranquil')
  }

}

Export-ModuleMember -Function Build-TranquilServer
Export-ModuleMember -Function Add-TranquilServerPackage
