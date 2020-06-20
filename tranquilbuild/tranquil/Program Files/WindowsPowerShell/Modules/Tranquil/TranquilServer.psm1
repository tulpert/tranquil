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

 .Parameter Version
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
    [Parameter(Mandatory=$True)][String]$Version,
    [String]$Description,
    [Switch]$WhatIf
  )

  $ltx = '[BuildServer] '

  # Check the variables that no crazy characters are input
  if ( $Version -iNotMatch "^[a-z0-9]*$") {
    Write-Warning ("Version must only contain alphanumeric characters (in lowercase)")
    return $False
  }

  # First ensure that all directories exist 
  $BaseDir  = $BaseDirectory -Replace "[\/]*$", ''
  $DistsDir = $BaseDir + '/dists/' + $version
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
    'Date'          = (Get-Date)
    'Codename'      = $version
    'Architectures' = "aAa"
    'Components'    = "cCCc"
    'Description'   = $Description
  }
  if ( ! $WhatIf ) {
    # Only create a new InRelease file if it doesn't already exist
    if ( ! (Test-Path -PathType Leaf $ReleaseFile )) {
      Write-Verbose ($ltx + "Creating initial release file: " + $ReleaseFile)
      $ReleaseContents | Out-File -Encoding utf8 -FilePath $ReleaseFile
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
  Add-TranquilServerPackage -Package /path/to/package -BaseDirectory /path/to/server/files
  
 .Parameter Package
  Path to the package to add. The package will be read and imported into the correct Tranquil server directory path
  based on the metedata contained within the package (i.e. what the "TRANQUIL/control" file instructs. 

 .Parameter BaseDirectory
  The directory where the Tranquil server packages are stored

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
    [Parameter(Mandatory=$True)][String]$BaseDirectory,
    [String]$NumVersions = 1,
    [String]$Description,
    [Switch]$WhatIf
  )

  # Check that the basedirectory actually exists
  if ( -Not (Test-Path $BaseDirectory) ) {
    Write-Error ("BaseDirectory does not exist ...")
    exit (668)
  }

  # Check that the package actually exists and that is is a valid Tranquil package before continuing
  $CheckPackage = Update-TranquilServerPackageInfo -File $Package -BaseDirectory $BaseDirectory
  if ( -Not ($CheckPackage)) {
    Write-Error ("File is not a valid Tranquil package: Does not exist ...")
    Return $False
  }



}

# Will check if the file is a proper Tranquil Package and return... something...
# Function Get-TranquilPackageInfo {
Function Update-TranquilServerPackageInfo {
  Param (
    [Parameter(Mandatory=$True)][String]$File,
    [Parameter(Mandatory=$True)][String]$BaseDirectory,
    [Switch]$Delete = $False
  )

  $privvars       = Get-PrivateVariables
  $TempDir        = $privvars['TMPDIR']
  $lpx = '[PackageInfo] '
  
  if ( -Not ( Get-ChildItem -ErrorAction SilentlyContinue $File ) ) {  
    return $False
  }

  # Tests completed. Let's continue
  $_rand = Get-Random -Minimum 10000 -Maximum 99999
  $_dest = $TempDir + '/' + $_rand
  # Write-Host -ForegroundColor Blue $_dest
  New-Item -ErrorAction SilentlyContinue -ItemType Directory $_dest

  Expand-Archive -Force -Verbose:$False -Path $File -DestinationPath $_dest | Out-Null
write-host -ForegroundColor Blue $_dest

  # Now check if there is a control file present
  # write-host -ForegroundColor Blue ($_dest + '/' + $privvars['TRANQUILBUILD'] + '/control' )
  $_control = ($_dest + '/' + $privvars['TRANQUILBUILD'] + '/control' )

  # Check if Control file exists and returns any content
  Write-Verbose ( $ltx + "Checking content of control file: " + $_control)
  $_controlcontent = Get-Content $_control
write-host -ForegroundColor Blue ("This: " + $_controlcontent)
  if ( -Not $_controlcontent ) {
    Write-Error ($ltx + "Package is not a valid Tranquil file.")
    exit (667)
  }
  # Write-Host -ForegroundColor Blue ($_controlcontent)
  # Read the package metadata and find distribution packagename and version
  # to determine where to store the package meta content
  # Also check if all relevant metadata exists. We MUST have
  # * Package name  (package: <packagename>)
  # * Version       (version: 1.2.3)
  # 
  # The rest can be dedused or rely on defaults if not set
  #
  # TODO TODO TODO TODO
  # TODO TODO TODO TODO
  # TODO TODO TODO TODO
  # TODO TODO TODO TODO
  # TODO TODO TODO TODO
  # TODO TODO TODO TODO
  $FoundSection = $False
  $_controlcontent | % {
    Write-Host -ForegroundColor Blue ("TH2is: " + $_)
    if ( $_ -Match "^Section\:" ) {
      $SectionPath = ($_ -Replace "^Section\:\s*", "").Trim()
      $FoundSection = $True
      Break
    }
  }

  if ( $FoundSection ) {
    $SectionPath = (($BaseDirectory -Replace "[\/]*\s*$", "") + '/' + ($SectionPath))
  } else {
    $SectionPath = (($BaseDirectory -Replace "[\/]*\s*$", "")) + '/' + 'main'
  }
  Write-Verbose ( $ltx + "Using SectionPath: " + $SectionPath )

  # Reading contents of Package file (if exists).
  # if not exists, create a new Package file
  $_packagedest = $TempDir      + '/_Packages_' + $_rand
  $_ptmpfilegz  = $_packagedest + '/' + 'Packages.gz'
  $_ptmpfile    = $_packagedest + '/' + 'Packages'
  $_packagegz   = $SectionPath  + '/' + 'Packages.gz'
  $_packagefile = $SectionPath  + '/' + 'Packages'
  Write-Verbose ( $ltx + 'Using PckTmp: ' + $_packagedest )
  Write-Verbose ( $ltx + 'Working on Packages.gz: ' + $_packagegz)

  # Create a new section if it does not exist
  if ( ! ( Test-Path $SectionPath )) {
    try {
      New-Item -ItemType Directory $SectionPath
    } catch {
      Write-Error ("Could not create directory. Error 1515")
    }
  }

  # Create a new temp directory for the Package file
  if ( ! ( Test-Path $_packagedest )) {
    try {
      New-Item -ItemType Directory $_packagedest
    } catch {
      Write-Error ("Could not create directory. Error 1516")
    }
  }

  $_myCheck = Get-Item -ErrorAction SilentlyContinue $_packagegz
  # if ( (Test-Path $_packagegz) ) {
  if ( ($_myCheck.Exists) -And ( -Not $_myCheck.IsPsContainer) ) {
    Expand-Archive -ErrorAction SilentlyContinue -DestinationPath $_packagedest $_packagegz | Out-Null
  } 
  Write-Host ("---> " + $_packagedest)
  # Write-Host ("---> " + $_ptmpfile)
  $PackageContents = Get-Content -ErrorAction SilentlyContinue $_ptmpfile

Write-Host -ForegroundColor Cyan ("000> " + $PackageContents )

  # We will now read the contents of the Package.gz file for the newly added package's Section
  # If the package does not already exist, add it to Package
  # If the package already exists, check for changes and add it to the Package
  # We also want the Package file to be alphabetical by Package, Version
  # (This is where we check how many versions of the same package we will allow to retain) - Maybe...?

  # We will read continously through the package. Any blank line(s) deliniates the different packages
  # Add the packages to a HASH so we can sort it and inject it back
  $NewPackage = $True
  $NewPackageContents = @{}
  $PackageContents | % {
    if ( $NewPackage ) {
      $NewPackage = $False
      if ( $thisPackage.count -gt 0 ) {
        # We have found a package. Store it in our hash using Name+Version as a key
        $thisKey = (($thisPackage.Package).ToLower().Trim() +'-'+ ($thisPackage.Version).ToLower().Trim())
        if ( ! ($NewPackageContents.ContainsKey($thisKey)) ) {
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
      if ($_ -NotMatch "^\s*\#" ) {
        if ( $_ -Match "^[A-Z][a-z]*\:" ) {
          $mySplit = $_.Split(":")
          $thisPackage.Add($mySplit[0].ToLower(), $mySplit[1].ToLower())
        }
      }
    }
  }

Write-Host -ForegroundColor Blue ("IIIIIIIII>>>> " + $thispackage)

  # Now start the output of a package
  write-host -ForegroundColor Blue ("This is the NEW contents: " + $NewPackageContents )
  foreach($itemkey in $NewPackageContents.GetEnumerator() | Sort-Object Name ) {
    $NewOutput = ""
    # Write-Host -ForegroundColor Blue ("ItemKey: " + $itemkey.Name)
    # Write-Host -ForegroundColor Cyan ($NewPackageContents[$item.Name])
    # Write-Host -ForegroundColor Cyan ("Schnarf")
    foreach ( $packageitem in $NewPackageContents[$itemkey.Name] ) {
      # Write-Host -ForegroundColor Cyan ("" + $packageitem)
      # ($packageitem.Keys | foreach { Write-Host -ForegroundColor Blue "$_ $($packageitem[$_])" }) -join "|"
($packageitem.Keys | foreach { $NewOutput = $NewOutput + ($_.Trim()+": "+ $($packageitem[$_]).Trim()) + "`n" }) -join "|"
      $NewOutput = $NewOutput + "`n"
      # $ReleaseContents | Out-File -Encoding utf8 -FilePath $ReleaseFile
      $NewOutput | Out-File -Encoding utf8 -FilePath $_ptmpfile
    }
  }
  # Write-Host -ForegroundColor Blue ("NewOutput: `n")
  # Write-Host -ForegroundColor Blue ($NewOutput)
  # write-host -ForegroundColor blue ("  ----- || -----  ")

  # Write-Host -ForegroundColor Blue ("_Packagedest: " + $_packagedest)
  Compress-Archive -DestinationPath $_ptmpfilegz $_ptmpfile | Out-Null

  # Check that the new archive file has been created and move it into its final location
  $_myCheck = Get-Item -ErrorAction SilentlyContinue $_ptmpfilegz
  if ( ($_myCheck.Exists) -And ( -Not $_myCheck.IsPsContainer) ) {
    Write-Host -ForegroundColor Blue ("Moving from "+ $_ptmpfilegz+" TO " + $_packagegz )
    Move-Item -Force $_ptmpfilegz $_packagegz
  }

  # Cleaning up Package file temp directory
  if ( Get-Item -ErrorAction SilentlyContinue $_packagedest ) {
    # Write-Host   -ForegroundColor Blue ("Deleting : " +  $_packagedest )
    Write-Verbose ($ltx + "Removing tmp file: " + $_packagedest)
  }
  # Cleaning up main tmp directory
  if ( Get-Item -ErrorAction SilentlyContinue $_dest ) {
    # Write-Host   -ForegroundColor Blue ("Deleting : " +  $_dest )
    Write-Verbose ($ltx + "Removing tmp file: " + $_dest)
  }
  
  # Write-Host -ForegroundColor Blue "Schnarf"
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
