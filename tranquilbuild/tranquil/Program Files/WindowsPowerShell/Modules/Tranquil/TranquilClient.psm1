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
  [cmdletbinding()]
  Param (
    [String]$SourceDirectory
  )

  $privvars       = Get-PrivateVariables
  $lpx = "[Update] "

  if ( $SourceDirectory ) {
    $Sources = @($SourceDirectory, $privvars['SOURCEDIRS'])
  } else {
    $Sources = $privvars['SOURCEDIRS']
  }
  
  # Iterate through all Sources Directories and look for .list files
  # Then use those to update the local cache
  # The list file needs to contain atleast 3 columns. Spaces are (currently) not allowed
  # 1: 'tranquil'   - The word. Future use is to be determined
  # 2: url          - The base url to the location. Currently only supporting http/https urls. file support possibly in the future
  # 3: release      - Usually the codename for the release (or windows version) i.e. "win2016" or similar

  # $Sources now contains a list of possible .list directories
  $Sources | Foreach-Object {
    # Check that the directory actually exists
    $_source = Get-Item -ErrorAction SilentlyContinue $_
    if ( Test-Path "${_source}" ) {
      # Directory exists. Now let's get all .list files in this directory
      Write-Verbose ($lpx+"Checking sources dir for .list files: " + ($_source))
      $_listFiles = Get-ChildItem -Path $_ | Where-Object -Property Extension -Match "^.list$"
      $_listFiles | Foreach-Object {
        # Alright, we have a .list file. Now let's read the contents
        $_fileFullName = $_.FullName
        Write-Verbose ($lpx+"Syncing .list file: " + $_fileFullName)
        $_thislist = Get-Content -ErrorAction SilentlyContinue $_.FullName
        # We extracted have the contents of the .list file. Get the contents as an array
        # The file might contain multiple lines. Let's iterate!
        $_linenumber = 0
        $_thislist -Split "\n" | Foreach-Object {
          $_thisline = $_
          # We are now on a line in the .list file
          $_linenumber = $_linenumber + 1
          if ( $_thisline -notmatch "^\s*\#") {
            # This line does not start with a comment. Let's split the line and check the output
            $linesplit = Test-TranquilListString -ListString $_thisline
            if ( ! $linesplit) {
              Write-Warning ("Ignoring line " + [String]$_linenumber + " in file: " + $_fileFullName)
            } else {
              # Alright. Let's load the repo into local cache 
              $tmp = Sync-TranquilRemoteRepository -Url $linesplit[1] -Version $linesplit[2] -Component $linesplit[3]
            }
          }
        }
      }
      # Write-Host ( "Directory found. Loading .list files [${_source}]" )
    }
  } 
  Write-Host -ForegroundColor RED ($lpx+"THIS FUNCTION IS NOT FINISHED!")
}

#
# Will sync up a remote repository to local cache
#
# Files and Directories to look for:
# /dists/<version>/Release          - This will contain all package info, hashes and signed keys
# /dists/<version>/Release.gpg      - This will contain all package info, hashes and signed keys - but as a signed package. 
#                                     This is preferable but will only work if pgp or open gpg is available: https://www.gpg4win.org/
# /dists/<version>/by-hash/SHA256/  - This folder should contain same files as two levels down, only saved as filename SHA256 for added security
# 
Function Sync-TranquilRemoteRepository {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$Url,
    [Parameter(Mandatory=$True)][String]$Version,
    [Parameter(Mandatory=$True)][String]$Component
  )

  $lpx = '[SyncRepo] '
  $privvars       = Get-PrivateVariables
  # Check that the lists directory exists. If not - create it!
  $ListsDir  =  $privvars['LISTSDIR']
  if ( ! (Test-Path $ListsDir )) {
    Write-Verbose ($lpx + "No Lists directory found. Creating:" + $ListsDir)
    New-Item -ItemType Directory $ListsDir
  }
  $ListsTmp =  $ListsDir+'/spool'
  if ( ! (Test-Path $ListsTmp )) {
    New-Item -ItemType Directory $ListsTmp
  }

  # If we have GPG installed, fetch and verify the Release.gpg file 
  # If this fails, then we cannot trust this repository
  Write-Verbose ($lpx + "GPG Checking is not implemented yet!!!")

  # Create a list of everything to sync based on the provided data
  $FullUrl = ($Url.Trim() -Replace "[\/]*$", '') + '/dists/' + $Version
  $_myUri = [System.Uri]$FullUrl
  $DestFileName = [String]($_myUri.Host).ToLower()
  $DestFileName = $DestFileName + ( [String]($_myUri.AbsolutePath).ToLower() -Replace '/', '_')

  # Start syncing
  Write-Host ("Syncing with " + $FullUrl  + " ...")
  # Now fetch the InRelease file 
  $Target = 'InRelease'
  $Src    = ($FullUrl.Trim() -Replace "[\/]*$", '' ) + '/' + $Target
  $Dst    = ($ListsTmp + '/' + $DestFileName + '_' + $Target)
  Try {
    $WebRequestResult = Invoke-WebRequest -ErrorAction SilentlyContinue -Uri $Src -OutFile $Dst
  } Catch {
    Write-Warning ($lpx + "Bad repository found. Cannot sync with " + $FullUrl)
    Break
  }
  # Check that the file was successfully downloaded
  if ( Test-Path $Dst ) {
    Move-Item -Force $Dst $ListsDir
  }
# write-host -ForegroundColor Cyan $WebRequestResult

  # Write-Host -ForegroundColor Blue ($lpx + $Url)

  Write-Host -ForegroundColor RED ($lpx+"THIS FUNCTION IS NOT FINISHED!")
}  


# Takes a string as input and verifies that it is valid .list formatted contents
# and returns a list or $False if it is malformed
Function Test-TranquilListString {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$ListString
  )
  
  # Split the string (Does not take into account that a string might contain escaped spaces)
  $_mysplit = $ListString.Trim() -Split "\s+"

  # The tests:
  $EnoughVars = 4
  # Test 1: Do we have atleast 3 items in the string
  if ($_mysplit.count -lt $EnoughVars) {
    Write-Warning ("List file does not contain enough parameters. Wanted " + [String]$EnoughVars + " but found " + [String]($_mysplit.count)  + ".")
    return $False
  }

  # Test 2: Check if the first word is approved
  $TestCriteria = 'tranquil'
  if ($_mysplit[0] -NotMatch "${TestCriteria}") {
    Write-Warning ("Trigger word not found. Must meet criteria: " + ${TestCriteria} + ". Found: " + [String]$_mysplit[0]) 
    return $False
  }

  $TestCriteria = '^http[s]{0,1}\:\/\/[a-z0-9]+'
  # Test 3: Check if the url is valid
  if ($_mysplit[1] -NotMatch "${TestCriteria}") {
    Write-Warning ("URL is not valid. Must meet criteria: " + ${TestCriteria} + ". Found: " + [String]$_mysplit[1]) 
    return $False
  }

  $TestCriteria = '^[a-z0-9-_]+$'
  # Test 4: Check that the version is valid
  if ($_mysplit[2] -NotMatch "${TestCriteria}") {
    Write-Warning ("Version could not be determined. Must meet criteria: " + ${TestCriteria} + ". Found: " + [String]$_mysplit[2]) 
    return $False
  }
  
  $TestCriteria = '^[a-z0-9-_]+$'
  # Test 5: Check that the component is valid
  if ($_mysplit[2] -NotMatch "${TestCriteria}") {
    Write-Warning ("Component could not be determined. Must meet criteria: " + ${TestCriteria} + ". Found: " + [String]$_mysplit[3]) 
    return $False
  }
  
  return $_mysplit
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
  [cmdletbinding()]
  Param (
    $Name,
    [Switch]$Installed,
    [Switch]$ListContents
  )

  Write-Verbose ("Searching if package [${Name}] is installed on local system")

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
      # Plan and test for that

      # If specific packages have been requested, only return those. Else return everything
      # if ( ! $Name ) {
      $AddContents = $False
      # }
      $CacheDirItems | Foreach-Object {
        $_thisitem = $_
        $fileContents = Get-Content $_ | ConvertFrom-Json 
        # Check if the cache file actually contains any contents
        if ( $fileContents ) {
          $AddContents = $False
          if ( $Name ) {
            $Name | Foreach-Object {
              if ( ($_thisitem.basename).ToLower() -Match ($_).ToLower() ) {
                Write-Verbose ("Found package based on search criteria: " + ($_thisitem.basename).ToLower())
                $AddContents = $True
              } else {
                $AddContents = $False
              }
            }
          } else {
            $AddContents = $True
          }
          if ($AddContents) {
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
        # Reset the output if specific packages are queried
        if ( $Name ) {
          $AddContents = $False
        }
      }
    }
  }

  if ( $AllPackages ) {
    $AllPackages
  } else {
    Write-Verbose "No Packages based on search criteria found on this system"
    return $False
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
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$File,
    [String]$Root = "/",
    [Switch]$Force,
    [Switch]$WhatIf,
    [Switch]$ReInstall
  )

  $lpx="[Install] "

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

  Write-Verbose ($lpx+"Using TMP file: " + ${TMPFILE})
  Write-Verbose ($lpx+"Using DIR directory: " + ${TMPDIR})
  Copy-Item $File $TMPFile
  Expand-Archive -ErrorAction SilentlyContinue -Path $TMPFILE -DestinationPath $TMPDIR
  $TMPDirObject   = Get-Item -ErrorAction SilentlyContinue $TMPDIR
  if ( ! $TMPDirObject ) {
    Write-Error ("Could not extract package contents. Error 502")
    break
  }

  # Importing the CONTROL metadata
  $controlHash = Export-TranquilBuildControl -ControlFilePath ("${TMPDIR}/"+$privvars['TRANQUILBUILD']+"/control")
  $PackageName = $controlHash['Package']
  if ( ! $PackageName ) {
    Write-Error ("Package is corrupt. Cannot find value 'Package' in control file")
    break
  }

  # Get the latest cache info
  Write-Verbose ($lpx+"Reading cache from possible previous installs") 
  $currentCache = Get-TranquilCache -PackageName $PackageName

  if ( $currentCache.ContainsKey('meta') ) {
    if ( ($currentCache['meta'].version) -eq ($controlHash['version']) ) {
      if ( $ReInstall ) {
        Write-Verbose ($lpx+"ReInstall flag detected. Will overwrite existing installation")
      } else {
        Write-Host ('[' + $PackageName + "-" + $controlHash['version'] + "] is already installed. Use -ReInstall to reinstall")
        Break
      }
    }
  } 

  # Perform preinst scripts
  $preinst = Get-ChildItem -ErrorAction SilentlyContinue ($TMPDIR + "/"+$privvars['TRANQUILBUILD'] + "/") | ? name -match ("^preinst")
  if ( $preinst ) {
    Write-Verbose ($lpx+"Found and running preinst script") 
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
  Write-Verbose ($lpx+"Starting install")
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
        Write-Verbose ($lpx+"Ensuring temp directory exists and is writable: " + $Target)
        if ( ! (Test-Path $Target) ) {
          Write-Verbose ($lpx+"Creating: " + $Target)
          $newitem = New-Item -ErrorAction SilentlyContinue -ItemType Directory -Path "${Target}" 
        }
        if ( ! (Test-Path $Target) ) {
          Write-Error ("Could not create item [$Target]. Ensure you are running Installer as Administrator!") 
          exit (665)
        }
        Write-TranquilCache -Item ("${Target}") -PackageName $PackageName -PackageVersion $controlHash['version']
      }
    }

    # Now create subdirectories
    # Write-Verbose ($lpx+"Creating any new directories under: "  + $_.FullName)
    Get-ChildItem -Recurse $_.FullName | % {
      $Target = ($_.Fullname).Replace($TMPDirObject.FullName, "")
      if ( $_.PSIsContainer ) {
        if ( $WhatIf ) {
          Write-WhatIf -ForegroundColor Cyan ("Want to create: " + $Target)
        } else {
          Write-Verbose ($lpx+"Ensuring creation of directory (2): " + $Target)
          $newitem = New-Item -ErrorAction SilentlyContinue -ItemType Directory -Path "${Target}" 
          # if ($newitem) {
          Write-TranquilCache -Item ("${Target}") -PackageName $PackageName -PackageVersion $controlHash['version']
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
        if  ( $WhatIf ) {
          Write-WhatIf ("Want to ensure: " + $Target)
        } else {
          # TODO, Before installing - do a checksum to check if the file already exists and, if so, that the file was a part of the old package
          $writeItem = $True
          $oldItem = Get-Item -ErrorAction SilentlyContinue $Target 
          if ( $oldItem ) {
            # Item already exists. Check if it was part of an existing package
            if ( $currentCache.ContainsKey($Target) ) {
              # Item was already installed by this package. Check checksum
              # If not, and the file was created manually - throw a error/prompt for overwriting
              if ( $currentCache[$Target].Hash -NotMatch (Get-FileHash -ErrorAction SilentlyContinue $Target).Hash ) {
                Write-Host ("Item [${Target}] has been changed from previous installation.")
                $yN = 'PENGUIN'
                While ( $yN -notmatch "^n$|^y$" ) {
                  $yN = Read-Host (" Do you want to overwrite with new version (y/N)?")
                  if ( $yN -match "^$" ) { $yN = 'n' } else {}
                }
                if ( $yN -match "^n$" ) { $writeItem = $False } else { Write-Verbose ($ltx+"Will overwrite with packaged version ...") }
              }
            } else {
              # Item exists but is _not_ part of a known package
              $backupfile = ($Target) + "_" + (Get-Random(100000))
              Write-Host ("Creating backup of existing file: " + $backupfile)
              Move-Item -Force -ErrorAction SilentlyContinue $Target $backupfile
              $writeItem = $True
            }
          }
          Write-Verbose ($lpx+"Moving file into place: ${Source} --> ${Target}")
          if ( $writeItem ) {
            $SourceHash = (Get-FileHash (Get-Item $Source)).Hash
            Move-Item -Force -ErrorAction SilentlyContinue "${Source}" "${Target}"
            # Verify that the file has been created
            $veri = Get-Item -ErrorAction SilentlyContinue "${Target}"
            $TargetHash = (Get-FileHash $veri).Hash
            if ( $SourceHash -Like $TargetHash ) {
              if ($veri) {
                Write-TranquilCache -Item $veri.fullname -PackageName $PackageName -PackageVersion $controlHash['version']
              } else {
                Write-Warning ($ltx+"Could not verify the new file ["+($veri.FullName)+"] has been created ...")
              }
            } else {
              Write-Warning ($ltx+"Could not verify the new filehash equals the packaged filehash ...")
            }
          }
        }
      }
    }

  }
  Write-Verbose ($lpx+"Done install")

  # Perform postinst scripts
  $postinst = Get-ChildItem -ErrorAction SilentlyContinue ($TMPDIR + "/"+$privvars['TRANQUILBUILD'] + "/") | ? name -match ("^postinst")
  if ( $postinst ) {
    Write-Verbose ($lpx+"Found and running postinst script") 
    Write-Warning ("PostInst Not implemented yet") 
  }

  Remove-Item -ErrorAction SilentlyContinue $TMPFILE
  Remove-Item -Recurse -ErrorAction SilentlyContinue $TMPDirObject
}

<#
 .Synopsis
  Will uninstall installed tranquil package

 .Description
  Will search and remove all files installed by the tranquil package

 .Example
  # Quite easy
  UnInstall <packagename>
  
 .Parameter Force
  Do not ask if you want to remove package

 .Parameter ForceModified
  Do not prompt if detecting modified items

 .Parameter Verbose
  Prints out Verbose information during run

 .Parameter WhatIf
  Only prints out what to do, but does not actually do it
#>
Function Uninstall-TranquilPackage {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)]$Name,
    [Switch]$Force,
    [Switch]$ForceModified
  )
  # LogPrefix
  $lpx = "[Uninstall] "

  $privvars       = Get-PrivateVariables

  # First test to see if the package is actually installed on the system
  Write-Verbose ($lpx+"Checking if package [${Name}] is installed ...")
  $packages = Get-TranquilPackage -Name $Name
  if ( $packages ) {
    Write-Verbose ($lpx +"Found installed package. Will start uninstall ...")
    Write-Host ("This will uninstall the following packages:")
    $packages | out-host
    if ( $Force ) { $Yn = 'y'}
    While ($Yn -notmatch "^y$|^n$") {
      $Yn = Read-Host ("Do you want to continue? (Y/n)")
      if ($Yn -match "^$" ) {
        $Yn = "Y"
      }
      $Yn = $Yn.ToLower()
    }
    if ($Yn.ToLower() -match "^n$") {
      Break
    }
    
    # First run through files and remove those.
    # We'll create a list of directories and run through those at the end
    $allDirectories = @()
    
    $packages | Foreach-Object {
      $_thispackage = $_
      # Get the cached info about the package.
      # Note: Get-TranquilCache returns a hashtable
      $_thiscache = Get-TranquilCache -PackageName $_thispackage.name
      # Run through the items in the cache until they are deleted or signed out
      $_thiscache.Keys | Foreach-Object {
        $_mykey = $_
        # We will run some test. Only if all tests pass will we set $deleteok to $True and we are allowed to delete the item
        $deleteisok = $False
        if (($_mykey).toLower() -NotLike ($privvars['METAKEY']).ToLower()) {
          Write-Verbose ($lpx+"Working on " + ($_thiscache[$_mykey].item))
          # Don't actually do anything if the item is a protected item
          if (Test-TranquilProtectedItem -Item ($_thiscache[$_mykey].item)) {
            Write-Verbose ($lpx+($_thiscache[$_mykey].item) + " is protected. Will not uninstall or modify")
            $deleteisok = $False
            Write-Verbose ("Item is a protected directory or file. Will not delete: [" + "--" + "]")
          } else {
            # Hash is empty if item is a directory ( or maybe the hash is missing for some reason...)
            if ( $_thiscache[$_mykey].hash ) {
              if ( Test-TranquilHash -Item ($_thiscache[$_mykey].item) -Hash $_thiscache[$_mykey].hash ) {
                # File is confirmed to have same hash as installed chached version
                $deleteisok = $True
              } else {
                Write-Warning ($lpx+($_thiscache[$_mykey].item)+" has been modified.")
                if ($ForceModified) { 
                  $Yn = 'Y'
                  Write-Warning ($lpx+"ForceModified switch detected! Removing item ...")
                  $deleteisok = $True
                }
                $Yn = "ZEBRA"
                While ($Yn -notmatch "^y$|^Y$|^n$|^N$") {
                  $Yn = Read-Host ("Would you like to remove item? (Y/n)")
                  if ($Yn -match "^$" ) {
                    $Yn = "Y"
                  }
                }
              }
              if ( $Yn -match "^y$" ) {
                $deleteisok = $True
              } else {
                $deleteisok = $False
              }
            } else {
              # This item is not in the cache. Do not delete
              Write-Verbose ("Item is not in cache. Will not delete: [" + "--" + "]")
              $deleteisok = $False
            }
            $_Item = Get-Item -ErrorAction SilentlyContinue ($_thiscache[$_mykey].item)
            if ($_Item) {
              if ( ($_item.PSIsContainer) ) { 
                # This is a directory 
                $allDirectories += $_item
              } else {
                if ( $deleteisok ) {
                  Write-Verbose ($lpx+"Checks complete. Will uninstall item: " + ($_thiscache[$_mykey].item))
                  # This is a file. Let's remove it
                  Write-Verbose ($lpx+"Removing: " + $_Item.FullName)
                  if ( Test-Path $_Item.FullName ) {
                    if ($WhatIf) {
                      Write-Host -ForegroundColor Cyan ("[WhatIf] Would delete item [" + $_Item.FullName + "]")
                    } else {
                      if ($deleteisok) {
                        Remove-Item -ErrorAction SilentlyContinue ($_Item.FullName)
                        $deleteisok = $False
                      } else {
                        Write-Host -ForegroundColor Blue ("CHECKS FAILED. Create Bug report in GitHub: ["+$_Item.FullName+"]")
                      }
                    }
                  }
                }
              }
            }
          }
        } 
      }
      # Now run through the directories. They should now be empty and none of them should be protected
      # BUT it could be that we try to delete a parent directory before the child is removed. 
      # Which is why we will iterate a sorted array by path length
      # $allDirectories | Sort-Object { $_.Value.Length }
      $allDirectories | Sort-Object -Descending { $_.FullName.Length } | %{
        Write-Verbose ($lpx+"Attempting to remove directory: " + ($_.FullName))
        $_children = Get-ChildItem -ErrorAction SilentlyContinue $_
        if ( (($_children) | Measure-Object).Count -eq 0 ) {
          # Directory is empty. Let's delete
          try {
            Remove-Item -ErrorAction SilentlyContinue $_ 
            Write-Verbose ($lpx+"Directory removed: [" + ($_.FullName) +"]")
          } catch {
            Write-Warning ("Could not remove directory: " + ($_.FullName))
          }
        }
      } 
      
      # Remove Cache
      $_cachepath = Get-TranquilCache -PackageName $_thispackage.Name -ReturnPath
      if ( Test-Path ($_cachepath)) {
        Remove-Item $_cachepath
      }
      Write-Host ("Finished removing package " + $_thispackage.Name)
    }
  } else {
    Write-Verbose ($lpx+"Nothing to uninstall")
    return $False
  }

  Write-Host ("Done")
}

 #    [cmdletbinding( DefaultParameterSetName='Name')]
 #    Param(
 #        [Parameter(ParameterSetName='Name', Mandatory = $true)] [Parameter( ParameterSetName='ID')] [String] $Name,
 #        [Parameter( ParameterSetName='ID')] [int] $ID
 #    )

#
# Checks the filehash of an item from the package hash and returns true/false
Function Test-TranquilHash {
  [CmdletBinding(DefaultParameterSetName='ByHash')]
  Param (
    [Parameter(Mandatory=$True, ParameterSetName='ByPackage')][Parameter(Mandatory=$True, ParameterSetName='ByHash')][String]$Item,
    [Parameter(Mandatory=$True, ParameterSetName='ByPackage')][String]$Package,
    [Parameter(Mandatory=$True, ParameterSetName='ByHash')][String]$Hash
  )
  $retval = $False
  if ( $Hash ) {
    if ( Test-Path $Item ) {
      if ((Get-FileHash $Item).Hash -Like $Hash) {
        $retval = $True
      }
    }
  } else {
    if ( $Package ) {
      Write-Warning ("----> NOT IMPLEMENTED YET <----")
      $retval = $False
    }
  }
  return $retval
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
  [cmdletbinding()]
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
  [cmdletbinding()]
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
  if ( ! $controlHash['Package'] ) {
    Write-Host ("CONTROL file must contain Key 'Package'")
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
}

# This returns a Hash of global private variables in this module
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

#
# This handles registering and de-registering of created items in Cache
#
Function Write-TranquilCache {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$Item,
    [Parameter(Mandatory=$True)][String]$PackageName,
    [Parameter(Mandatory=$True)][String]$PackageVersion,
    [Switch]$Directory
  )

  #
  # Only update the cache if this is not a protected item
  #
  if ( ! (Test-TranquilProtectedItem -Item $Item) ) {
    $privvars       = Get-PrivateVariables

    $itemtype     = 'unused'
    $itemMetaData = @{
      'type'    = $itemtype
      'hash'    = (Get-FileHash -ErrorAction SilentlyContinue $Item).Hash
      'item'    = ($Item)
      'name'    = ($Item)
      'name_is_deprecated'    = ($Item)
      'version'  = $PackageVersion
    }
    $meta = @{
      version     = $PackageVersion
      package     = $PackageName
    }

    # Gets existing cache or create new cache
    $_cache = Get-TranquilCache -PackageName $PackageName
    if ( ! $_cache ) {
      Write-Verbose ("No cache file found for ${PackageName}")
      $_cache = @{}
    }

    # Create or update meta content
    if ($_cache.ContainsKey($privvars['METAKEY'])) {
      $_cache[$privvars['METAKEY']].version = $PackageVersion
      # $_cache[$privvars['METAKEY']].package = $PackageName.ToLower()
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
  }
}

<#
 .Synopsis
  Retrieve the Cache as a Hash where packagename is the key

 .Description
  Retrieve the Cache as a Hash where packagename is the key

 .Example
  # Quite easy
  Get-TranquilCache <PackageName>

 .Parameter PackageName
  Name of the Package. Can be a part of the package name. Will return all entries that match the search

 .Parameter ReturnPath
  Will return the actual Path to the package cache
#>
Function Get-TranquilCache {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$PackageName,
    [Switch]$ReturnPath
  )

  $privvars       = Get-PrivateVariables
  $cachedir       = $privvars['CACHE']
  $cacheFile      = ($privvars['CACHE']+"/"+"${PackageName}")
  if ( $ReturnPath ) {
    return $cacheFile
    Break
  }

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
    '^[/\\]*programdata[/\\]*$'
    '^[/\\]*windows[/\\]*$'
    '^[/\\]*users[/\\]*$'
    '^[/\\]*system32[/\\]*$'
    '^[/\\]*temp[/\\]*$'
    '^[a-z]:[/\\]*$'
    '^[/\\]+$'
  )
  Return $protec
}

#
# Returns true if string is part of Protected Folders
# Returns false if not
#
Function Test-TranquilProtectedItem {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$Item
  )

  $val = $False
  Get-ProtectedItems | % {
    $_checkitem = $_.ToLower()
    if ( (($Item).ToLower()) -Match $_checkitem )  {
      Write-Verbose ("Found protected item: " + $Item)
      $val = $True
    }
  }
  Return $val
}

#
# Just a simple Write-Host wrapper to add WhatIf colours and output
#
Function Write-WhatIf {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$True)][String]$Message,
    [ValidateSet("Cyan", "Pink")][String]$ForegroundColor = "Cyan"
  )
  Write-Host -ForegroundColor $ForegroundColor ("[WhatIf] " + $Message)
}

Export-ModuleMember -Function New-TranquilPackage
Export-ModuleMember -Function Install-TranquilPackage
Export-ModuleMember -Function UnInstall-TranquilPackage
Export-ModuleMember -Function Get-TranquilPackage
Export-ModuleMember -Function Update-Tranquil
