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
Export-ModuleMember -Function Build-TranquilServer
