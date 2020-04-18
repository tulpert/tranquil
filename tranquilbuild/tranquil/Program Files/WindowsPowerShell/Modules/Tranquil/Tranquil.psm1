<#
 .Synopsis
  Will update the Tranquil cache and list of available packages to install

 .Description
  Will update the Tranquil cache and list of available packages to install

 .Example
  # Quite easy
  Update-Tranquil 
  
 .Parameter SourceDirectory
  Path to the directory containing the .list packages. By default, Tranquil will search in c:/programdata/tranquil/sources or /etc/tranquil/sources

 .Parameter Verbose
  Prints out Verbose information during run

 .Parameter Force
  Forces the install even if errors have been detected or access rights (run as Administrator) are not in place

 .Parameter WhatIf
  Only prints out what to do, but does not actually do it
#>
Function Update-Tranquil {
  Param (
    [String]$SourceDirectory
  )

  $privvars       = Get-PrivateVariables

  if ( $SourceDirectory ) {
    $Sources = @($SourceDirectory, $privvars['SOURCEDIRS'])
  } else {
    $Sources = $privvars['SOURCEDIRS']
  }
  
  # Iterate through all Sources Directories and look for .list files
  # Then use those to update the local cache
  $Sources | Foreach-Object {
    $_source = $_
    if ( Test-Path $_source ) {
      Write-Host ( "Directory found. Loading .list files [${_source}]" )
    }
  } 
  $Sources
  Write-Host ("THIS FUNCITON IS NOT FINISHED")
}


<#
 .Synopsis
  Will get installed packages, their version and other metadata

 .Description
  Will get installed packages, their version and other metadata

 .Example
  # Quite easy
  Get-Tranquil 
  
 .Parameter SourceDirectory
  Path to the directory containing the .list packages. By default, Tranquil will search in c:/programdata/tranquil/sources or /etc/tranquil/sources

 .Parameter Verbose
  Prints out Verbose information during run

 .Parameter Force
  Forces the install even if errors have been detected or access rights (run as Administrator) are not in place

 .Parameter WhatIf
  Only prints out what to do, but does not actually do it
#>
Function Get-TranquilPackage {
  Param (
    [String]$Name,
    [Switch]$Installed,
    [Switch]$ListContents
  )


  # TODO: Create something to read from external repo's here!
  $AllPackages = @()

  # Get the module's private variables
  $privvars       = Get-PrivateVariables
  $CACHEDIR = $privvars['CACHE']
  if ( $CACHEDIR ) {
    $CacheDirItems = Get-ChildItem -ErrorAction SilentlyContinue $CACHEDIR
    if ($CacheDirItems) {  
      # The Cache files are JSON objects, however...
      # Not all files in the CacheDir might be JSON objects. Some may have been corrupted
      # Plan for that
      $CacheDirItems | Foreach-Object {
        $fileContents = Get-Content $_ | ConvertFrom-Json 
        if ( $fileContents ) {
          $_version = $fileContents.($privvars['METAKEY']).version
          if ( ! $_version ) {
            $_version = 'unknown'
          } 
          $_contents = New-Object PSObject
          $_contents | Add-Member -MemberType NoteProperty -Name Name -Value $_.name
          $_contents | Add-Member -MemberType NoteProperty -Name Version -Value $fileContents.($privvars['METAKEY']).version
          $_contents | Add-Member -MemberType NoteProperty -Name LastUpdatedTime -Value $_.lastupdatedtime
          $_contents | Add-Member -MemberType NoteProperty -Name Type -Value $_.type
          $AllPackages += $_contents
        }
      }
    }
  }

  if ( $AllPackages ) {
    $AllPackages # .PSObject.Properties.Name
  } else {
    Write-Verbose "No Packages found on this system"
  }
}

<#
 .Synopsis
  Will extract and install a Tranquil file onto Windows systems

 .Description
  Takes .tp/.tpam/.tranquil file as input, extracts content and runs installation routine

 .Example
  # Quite easy
  Install-TranquilPackage <package_file>
  
 .Parameter File
  Path to the package file. This is the default parameter.

 .Parameter ReInstall
  Runs installation on an already installed package. Will overwrite existing installation.

 .Parameter Verbose
  Prints out Verbose information during run

 .Parameter Force
  Forces the install even if errors have been detected or access rights (run as Administrator) are not in place

 .Parameter WhatIf
  Only prints out what to do, but does not actually do it
#>
Function Install-TranquilPackage {
  Param (
    [Parameter(Mandatory=$True)][String]$File,
    [String]$Root = "/",
    [Switch]$Force,
    [Switch]$WhatIf,
    [Switch]$ReInstall
  )
  if ( ! ((whoami) -match "root|administrator") -or ($Force) ) {
    Write-Error ("You should run installer as Administrator! Use -Force to override at your own risk.")
    break
  }

  # Get the module's private variables
  $privvars       = Get-PrivateVariables
  $MYRANDOM       = "tranquil_tmp_" + $privvars['RUNID']
  $TMPDIR         = $privvars['TMPDIR'] + "/" + $MYRANDOM
  $TMPFILE        = $TMPDIR + ".tmp.zip"

  # First check if the file being references for installation actually exists
  $installfile = Get-Item -ErrorAction SilentlyContinue $File
  if ( ! ( ($installfile) -And ($installfile.PSIsContainer -eq $False )) ) {
    Write-Error ("Installation package not found: " + [string]$File)
    Break
  }

  Write-Verbose ("Using TMP file: " + ${TMPFILE})
  Write-Verbose ("Using DIR directory: " + ${TMPDIR})
  Copy-Item $File $TMPFile
  Expand-Archive -ErrorAction SilentlyContinue -Path $TMPFILE -DestinationPath $TMPDIR
  $TMPDirObject   = Get-Item -ErrorAction SilentlyContinue $TMPDIR
  if ( ! $TMPDirObject ) {
    Write-Error ("Could not extract package contents. Error 502")
    break
  }

  # Importing the CONTROL metadata
  $controlHash = Export-TranquilBuildControl -ControlFilePath ("${TMPDIR}/"+$privvars['TRANQUILBUILD']+"/control")

  # Get the latest cache info
  Write-Verbose ("Reading cache from possible previous installs") 
  $currentCache = Get-Cache -PackageName $controlHash['Name']

  if ( $currentCache.ContainsKey('meta') ) {
    if ( ($currentCache['meta'].version) -eq ($controlHash['version']) ) {
      if ( $ReInstall ) {
        Write-Verbose ("ReInstall flag detected. Will overwrite existing installation")
      } else {
        Write-Host ('[' + $controlHash['Name'] + "-" + $controlHash['version'] + "] is already installed. Use -ReInstall to reinstall")
        Break
      }
    }
  } 

  # Perform preinst scripts
  # write-host ("----> " + ($TMPDIR + "/"+$privvars['TRANQUILBUILD'] + "/"))
  $preinst = Get-ChildItem -ErrorAction SilentlyContinue ($TMPDIR + "/"+$privvars['TRANQUILBUILD'] + "/") | ? name -match ("^preinst")
  if ( $preinst ) {
    Write-Verbose ("Found and running preinst script") 
    Write-Warning ("PreInst Not implemented yet") 
  }

  # Copying in the files
  #
  # We do two things. 
  #
  # 1: We run through and verify that all the directories are created correctly
  # 2: We run through the files and move them into place
  # 3: TODO: Look at file ownerships and permissions
  # 4: TODO: Register all files and folders with md5sums in a registry somewhere for future un-installations
  #
  Write-Verbose ("Starting install")
  $MoveThis = Get-ChildItem -ErrorAction SilentlyContinue $TMPDIR
  $MoveThis | ? -Property Name -NotMatch ("^" + $privvars['TRANQUILBUILD'] + "$") |  % {
    # 1
    # Create any base directories
    # It's stupid having to replicate code like this. If you find any clever workaround, that'd be great
    #
    if ( $_.PSIsContainer ) {
      $Target = ($_.Fullname).Replace($TMPDirObject.FullName, "")
      if ( $WhatIf ) {
        Write-WhatIf ("Want to create: " + $Target)
      } else {
        Write-Verbose ("Ensuring temp directory exists and is writable: " + $Target)
        if ( ! (Test-Path $Target) ) {
          Write-Verbose ("Creating: " + $Target)
          $newitem = New-Item -ErrorAction SilentlyContinue -ItemType Directory -Path "${Target}" 
        }
        if ( ! (Test-Path $Target) ) {
          Write-Error ("Could not create item [$Target]. Ensure you are running Installer as Administrator!") 
          exit (665)
        }
        Write-Cache -Item ("${Target}") -PackageName $controlHash['Name'] -PackageVersion $controlHash['version']
      }
    }

    # Now create subdirectories
    # Write-Verbose ("Creating any new directories under: "  + $_.FullName)
    Get-ChildItem -Recurse $_.FullName | % {
      $Target = ($_.Fullname).Replace($TMPDirObject.FullName, "")
      if ( $_.PSIsContainer ) {
        if ( $WhatIf ) {
          Write-WhatIf -ForegroundColor Cyan ("Want to create: " + $Target)
        } else {
          Write-Verbose ("Ensuring creation of directory (2): " + $Target)
          $newitem = New-Item -ErrorAction SilentlyContinue -ItemType Directory -Path "${Target}" 
          # if ($newitem) {
          Write-Cache -Item ("${Target}") -PackageName $controlHash['Name'] -PackageVersion $controlHash['version']
          #}
        }
      }
    }

    #
    # 2
    # 
    # Ensure all files are installed
    #

    Get-ChildItem -Recurse $_.FullName | % {
      if ( ! $_.PSIsContainer ) {
        $Source = $_.FullName
      $Target = ($_.Fullname).Replace($TMPDirObject.FullName, "")
      #   $newFile = ($_.Fullname).Replace($TMPDirObject.FullName, "")
        if  ( $WhatIf ) {
          Write-WhatIf ("Want to ensure: " + $Target)
        } else {
          Write-Verbose ("Moving file into place: ${Source} --> ${Target}")
          # TODO, Before moving - do a checksum to verify that the file was a part of the old package
          # If not, and the file was created manually - throw a error/prompt for overwriting
          Move-Item -ErrorAction SilentlyContinue "${Source}" "${Target}"
          # $newitem = New-Item -ErrorAction SilentlyContinue -Path "${Target}" 
          # Verify that the file has been created
          $veri = Get-Item -ErrorAction SilentlyContinue "${Target}"
          if ($veri) {
            Write-Cache -Item $veri.fullname -PackageName $controlHash['Name'] -PackageVersion $controlHash['version']
          }
        }
      }
    }

  }
  Write-Verbose ("Done install")

  # Perform postinst scripts
  $postinst = Get-ChildItem -ErrorAction SilentlyContinue ($TMPDIR + "/"+$privvars['TRANQUILBUILD'] + "/") | ? name -match ("^postinst")
  if ( $postinst ) {
    Write-Verbose ("Found and running postinst script") 
    Write-Warning ("PostInst Not implemented yet") 
  }


  # $_mydir     = Get-Item -ErrorAction SilentlyContinue $BuildDirectory
  # $_mybuild   = Get-Item -ErrorAction SilentlyContinue ($BuildDirectory + "/"+$TRANQUILBUILD+"/" )
  Remove-Item -ErrorAction SilentlyContinue $TMPFILE
  # Remove-Item -Recurse -ErrorAction SilentlyContinue $TMPDIR
}

<#
 .Synopsis
  Will create .tp package from correctly structure build folder hierarcy.

 .Description
  Expects parameter to be a folder with the correct file contents. Refer to documentation xxxx for details

 .Example
  # Quite easy
  New-TranquilPackage <build_directory>
  
 .Parameter BuildDirectory
  Path to the build directory. This is the default parameter.

 .Parameter Verbose
  Prints out Verbose information during run

 .Parameter WhatIf
  Only prints out what to do, but does not actually do it
#>
Function New-TranquilPackage {
  Param (
    [Parameter(Mandatory=$True)][String]$BuildDirectory,
    [String]$OutFile
  )

  # Get the module's private variables
  $vars = Get-PrivateVariables
  $TRANQUILBUILD    = $vars['TRANQUILBUILD']
  $PKGEXTENSION     = $vars['PKGEXTENSION']
  $DEFAULTCOMPRESS  = $vars['DEFAULTCOMPRESS']
  $RUNID            = $vars['RUNID']
  $TMPFILE          = $vars['TMPDIR'] + "/tranquil_tmp_" + $RUNID + ".tmp" + $DEFAULTCOMPRESS

  Write-Verbose ("Using TMP file: " + ${TMPFILE})

  $_mydir     = Get-Item -ErrorAction SilentlyContinue $BuildDirectory
  $_mybuild   = Get-Item -ErrorAction SilentlyContinue ($BuildDirectory + "/"+$TRANQUILBUILD+"/" )

  # Check if the BuildDirectory is a valid directory
  if ( ($_mydir.PSIsContainer) -And ($_mybuild.PSIsContainer) ) {
    Write-Verbose ("Build container located: " + $_mybuild.fullname)
  } else {
    Write-Error ("BuildDirectory does not exist or control files are missing")
    Break
  } 

  # If outfile is specificed, ensure we do not try to overwrite the users wishes
  # If outfile is not specificed, just use the foldername as name
  if ( $OutFile ) {
    $DontMessWithOutFile = $True
  } else {
    $OutFile = $_mydir.BaseName 
  }
  $OutFile = $OutFile -Replace "${DEFAULTCOMPRESS}$", ""

  # Now let's check if the BuildDirectory contains the required directories and files
  # It must have a /TRANQUIL/control file
  # It _can_ have 
  # - /TRANQUIL/postinst
  # - /TRANQUIL/preinst
  # - /TRANQUIL/postrm
  # - /TRANQUIL/prerm
  #
  # We will check if these files exist with _any_ fileending.
  #

  # Store the BUILD directory as a variable
  $bd = ($_mydir.FullName + "/" + $TRANQUILBUILD)

  #
  # 1: CONTROL file
  #
  $controlFile = Get-Item -ErrorAction SilentlyContinue ($bd + "/control*")
  $controlDict = @{}
  $mustexit = $False
  if ( ($controlFile) ) {
    if ( (Get-Item -ErrorAction SilentlyContinue -Path $controlFile | Where-Object -Property BaseName -Match "^control" | Measure-Object).Count -eq 1 ) {
    }
    # These exists a CONTROL file and only one
  } else {
    Write-Error ("Make sure there exists one and only one CONTROL file")
    $mustexit = $True
  }

  "preinst", "postinst", "prerm", "postrm" | Foreach-Object {
    $scriptFile = Get-Item -ErrorAction SilentlyContinue ($bd + "/" + $_ + "*")
    if ( ($scriptFile | Measure-Object).Count -gt 1 ) {
      Write-Error ("Detected multiple " + $_ + " files. There can be only one")
      $mustexit = $True
    }
  }

  if ($mustexit) {
    Break
  }

  $controlHash = Export-TranquilBuildControl -ControlFilePath $controlFile.FullName


  if ($controlHash -And $controlHash.count -gt 0) {
    Write-Verbose ("Successfully validated data from CONTROL file")
  } else {
    Write-Error ("CONTROL file is malformed")
    Break
  }
  if ( $DontMessWithOutFile ) { 
    $NewPackageName = ($OutFile + $PKGEXTENSION)
  } else {
    $NewPackageName = ($OutFile+"-"+$controlHash['version'] + $PKGEXTENSION)
  }

  Write-Verbose ("Will build package [" + $NewPackageName + "]")
  # Check if TMPFILE already exists. That could happen for unforseen reasons.
  # Try {
  #   Write-Host "Compress-Archive -ErrorAction SilentlyContinue -Path ((${_mydir}.fullname)+'/*') -DestinationPath (${TMPFILE}) -Force"
  # Compress-Archive -ErrorAction SilentlyContinue -Path (($_mydir.fullname)+"/*") -DestinationPath ($TMPFILE) -Force
  Compress-Archive -Path (($_mydir.fullname)+"/*") -DestinationPath ($TMPFILE) -Force
  # } Catch {
  #   Write-Error ("Open files exist in package directory. Close all files and try again")
  #   Break
  # }
  # Check for Compressed file and rename to keep with our file ending
  $NewPackage = Get-Item -ErrorAction SilentlyContinue $TMPFILE

  # Check if an old package already exists and query user if they want to overwrite
  $checkfile = Get-Item -ErrorAction SilentlyContinue $NewPackageName
  if ( $checkfile.exists ) {
    While ($Yn -notmatch "^y$|^Y$|^n$|^N$") {
      $Yn = Read-Host ("Found file [ "+$checkfile.fullname+" ]`nDo you want to overwrite (Y/n)")
      if ($Yn -match "^$" ) {
        $Yn = "Y"
      }
    }
    if ( $Yn -match "n|N") {
      Break 
    }
    Remove-Item -Force $checkfile
  }
  
  if ( $NewPackage ) {
    Move-Item -Force ($NewPackage.FullName) $NewPackageName
  }
}



# This is a private function to check and validate that the CONTROL file
# has correct contents and is valid
Function Export-TranquilBuildControl {
  Param (
    [Parameter(Mandatory=$True)][String]$ControlFilePath
  )
  $controlHash = @{}

  # Iterate through the lines in the control file and extract data as a Hash
  $currentKey   = ""
  $currentValue = ""
  Get-Content -ErrorAction SilentlyContinue ($ControlFilePath) | ForEach-Object {
    $line         = $_
    if ( $line -match "^[a-zA-Z]+\:\s*") {
      # We've found a new key. Save the old key and value (if exists) and reset
      if ($currentKey -And $currentValue) {
        $controlHash.Add($currentKey.tolower(), $currentValue)
      }
      $currentKey   = ( $line -Replace "\:\s*.*$", "")
      $currentValue = ( $line -Replace "^[a-zA-Z0-9]+\:\s*", "")
    } else {
      # This codeblock handles lines that are _not_ prefixed by a key. Add to value and remove any blank newlines
      if ( $line -match "^\s[a-zA-Z0-9_-]+" ) {
        $currentValue = ($currentValue + "`n" + ($line.Trim()))
        # $currentValue = $tmp
      } elseif ( $line -match "^\s\.\s*$" ) {
        $currentValue = ($currentValue + "`n")
      }
    }
  }
  # Add the final Key and Value
  if ($currentKey -And $currentValue) {
    $controlHash.Add($currentKey, $currentValue)
  }

  # Now verify that we have all the keys that are required
  if ( ! $controlHash['Name'] ) {
    Write-Host ("CONTROL file must contain Key 'Name'")
    Return $false
  }
  if ( ! $controlHash['Maintainer'] ) {
    Write-Host ("CONTROL file must contain Key 'Maintainer'")
    Return $false
  }
  if ( ! $controlHash['Description'] ) {
    Write-Host ("CONTROL file must contain Key 'Description'")
    Return $false
  }
  if ( ! $controlHash['Version'] ) {
    Write-Host ("CONTROL file must contain Key 'Version'")
    Return $false
  }

  # if ($controlHash.count -gt 0) {
  Return $controlHash
  # } else {
  #   Return $False
  # }
}

# This returns a Hash of global variables in this module
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
    "STATEFILE"       = "${ProgramData}/statefile"
    "SOURCESDIR"      = "${ProgramData}/sources"
    "METAKEY"         = "__tranquilmeta__"
    "SCRIPTEXT"       = @(".txt", ".ps1", ".tp", , ".py", ".tpam", "")   # Not sure i will use this one
    "SOURCEDIRS"      = @("${ProgramData}/sources", '/etc/tranquil/sources', '~/.tranquil')
  }
}

#
# This handles registering and de-registering of created items in Cache
#
Function Write-Cache {
  Param (
    [Parameter(Mandatory=$True)][String]$Item,
    [Parameter(Mandatory=$True)][String]$PackageName,
    [Parameter(Mandatory=$True)][String]$PackageVersion,
    [Switch]$Directory
  )


  #
  # Only update the cache if this is not a protected item
  #
  if ( ! (Test-ProtectedItem -Item $Item) ) {
    write-host ("Working on: " + $Item)
    $privvars       = Get-PrivateVariables

    $itemtype     = 'unused'
    $itemMetaData = @{
      'type'    = $itemtype
      'hash'    = (Get-FileHash -ErrorAction SilentlyContinue $Item).Hash
      'name'    = ($Item)
      'version'  = $PackageVersion
    }
    $meta = @{
      version     = $PackageVersion
    }

    # Gets existing cache or create new cache
     $_cache = Get-Cache -PackageName $PackageName
    if ( ! $_cache ) {
      $_cache = @{}
    }

    # Create or update meta content
    if ($_cache.ContainsKey($privvars['METAKEY'])) {
      $_cache[$privvars['METAKEY']].version = $PackageVersion
    } else {
      $_cache.Add($privvars['METAKEY'], $meta)
    }

    if ( $_cache.containsKey($Item.tolower()) ) {
      # Write-Host -ForegroundColor Cyan ("Found existing cache key  NOT IMPLEMENTED")
      $_cache[($Item.tolower())] = $itemMetaData
    } else {
      # Write-Host -ForegroundColor Cyan ("Brand New cache key ["+($Item.tolower())+"]")
      $_cache.Add(($Item.tolower()), $itemMetaData)
    }

    # First ensure that the CACHE directory exists
    $cachedir = $privvars['CACHE']
    New-Item -ErrorAction SilentlyContinue -ItemType Directory "${cachedir}" | Out-Null

    Write-Verbose ("Registering item in cache: " + $Item.itemname)
    $cacheFile = ($privvars['CACHE']+"/"+"${PackageName}")
    Write-Verbose ("Updating Cache: " + $cacheFile)
    $_cache | ConvertTo-Json | Out-File -Encoding utf8 -FilePath $cacheFile
  } else {
    write-host ("Schnarf ! " + $ITEM)
  }
}


#
# Retrieve the Cache as a HASH where filename/directoryname is the key
#
Function Get-Cache {
  Param (
    [Parameter(Mandatory=$True)][String]$PackageName
  )

  $privvars       = Get-PrivateVariables
  $cachedir       = $privvars['CACHE']
  $cacheFile      = ($privvars['CACHE']+"/"+"${PackageName}")

  $cacheFile = Get-Item -ErrorAction SilentlyContinue ($privvars['CACHE']+"/"+"${PackageName}")
  $returnData = @{}
  if ( $cacheFile ) {
    Write-Verbose ("Found cache ["+$cacheFile+"]")
    (Get-Content -ErrorAction SilentlyContinue -Path ($cacheFile.FullName) | ConvertFrom-Json).PSObject.Properties | % { $returnData[$_.Name] = $_.Value }
  } else {
    $returnData = @{}
  }
  $returnData
}

#
# Returns an array of protected folders
# I.e. Folders that should not be tracked, modified or deleted
#
Function Get-ProtectedItems {
  $protec = @(
    '^[/\\]*program files[/\\]*$'
    '^[/\\]*program files (x86)^[/\\]*$'
    '^[/\\]*programdata^[/\\]*$'
    '^[/\\]*windows^[/\\]*$'
    '^[/\\]*users^[/\\]*$'
    '^[/\\]*system32^[/\\]*$'
    '^[/\\]*temp^[/\\]*$'
    '^c:[/\\]*$'
    '^[/\\]+$'
  )
  Return $protec
}

#
# Returns true if string is part of Protected Folders
# Returns false if not
#
Function Test-ProtectedItem {
  Param (
    [Parameter(Mandatory=$True)][String]$Item
  )

  $val = $False
  Get-ProtectedItems | % {
    if ( $Item -match $_ )  {
      Write-Verbose ("Found protected folder. Will not track in cache: " + $Item)
      $val = $True
    }
  }
  
  Return $val
}

#
# Just a simple Write-Host wrapper to add WhatIf colours and output
#
Function Write-WhatIf {
  Param (
    [Parameter(Mandatory=$True)][String]$Message,
    [ValidateSet("Cyan", "Pink")][String]$ForegroundColor = "Cyan"
  )
  Write-Host -ForegroundColor $ForegroundColor ("[WhatIf] " + $Message)
}

Export-ModuleMember -Function New-TranquilPackage
Export-ModuleMember -Function Install-TranquilPackage
Export-ModuleMember -Function Get-TranquilPackage
Export-ModuleMember -Function Update-Tranquil
