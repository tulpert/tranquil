<#
 .Synopsis
  Will setup and configure a Tranquil repository server

 .Description
  Will setup and configure a Tranquil repository server

 .Example
  Build-TranquilServer -Directory /path/to/directory -Version <serverversion>
  
  # Proper example to create a Windows 2016 repo server in an apache web directory on a Linux server
  Build-TranquilServer -Directory /var/www/html/tranquil/windows -Version win2016
  
 .Parameter Directory
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
    [Parameter(Mandatory=$True)][String]$Directory,
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
  $BaseDir  = $Directory -Replace "[\/]*$", ''
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
  Add-TranquilServerPackage -Package /path/to/package
  
 .Parameter Package
  Path to the package to add. The package will be read and imported into the correct Tranquil server directory path
  based on the metedata contained within the package (i.e. what the "TRANQUIL/control" file instructs. 

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
    [String]$NumVersions = 1,
    [String]$Description,
    [Switch]$WhatIf
  )

  # Check that the package actually exists and that is is a valid Tranquil package before continuing
  $CheckPackage = Get-TranquilPackageInfo -File $Package
  if ( -Not ($CheckPackage)) {
    Write-Error ("File is not a valid Tranquil package ...")
  }

}

# Will check if the file is a proper Tranquil Package and return... something...
Function Get-TranquilPackageInfo {
  Param (
    [Parameter(Mandatory=$True)][String]$File,
    [String]$TmpDir = '/'
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
  write-host -ForegroundColor Blue $_dest
  New-Item -ErrorAction SilentlyContinue -ItemType Directory $_dest

  Expand-Archive -Force -Verbose:$False -Path $File -DestinationPath $_dest

  # Now check if there is a control file present
  write-host -ForegroundColor blue ($_dest + '/' + $privvars['TRANQUILBUILD'] + '/control' )
  $_control = ($_dest + '/' + $privvars['TRANQUILBUILD'] + '/control' )

  Write-Verbose ( $ltx + "Checking content of control file: " + $_control)

  $_controlcontent = Get-Content $_control
  Write-Host -ForegroundColor Blue ($_controlcontent)

  if ( Get-Item -ErrorAction SilentlyContinue $_dest ) {
    Write-Host   -ForegroundColor Blue ("Deletnig : " +  $_dest )
    Write-Verbose ($ltx + "Removing tmp file: " + $_dest)
#     Remove-Item -Force -Recurse $_dest
  }

  
  Write-Host -ForegroundColor Blue "Schnarf"
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
