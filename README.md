#Tranquil Package Manager
For managing custom bespoke packages on Windows servers

##What is Tranquil and Why build it
Administrating custom scripts and applications for Windows Servers often require building and deploying these scripts onto the server itself.
I've found that creating .msi or .exe packages can be quite tedious and requires heavy .net frameworks or compiling .dll files. 
This in turn requires software to create and manage these packages. All of this is a heavy operational overhead.

I wanted to create a package manager that is extremely light-weight and uses _only_ built-in functions and core features in the Windows operating system.
For this, I use PowerShell. There might be one exception to this rule, and that is package signing for which I was thinking to use opengpg - but I haven't started that codebase yet... Maybe I'll find a built-in PowerShell function that supports gpg/pgp that I don't know about yet. The point is that the code is developed using a text editor and powershell. No reliance on VisualStudio or heavy DotNet frameworks. 
Just code.

Tranquil is built on the DEBIAN (.deb) package manager build process and the apt-get client

#Personal note:
Now that Microsoft have created their winget repository manager, this development effort might be dead in the water. I will continue to monitor MS's efforts 
and I truly hope they now create something that is easy to use, both as a client and as a server. 
I am delighted and miffed that winget got released. Delighted because this shows that MS finally acknowledges the need for a working package manager in their ecosystem
and slightly miffed because they had to go and release it _just_ as I finally got around to working on this project. But I really hope winget is successful! This has been sorely missed.

##My requirements to a package manager; 
* Easy to install and to use. Do not require heavy installers and multiple dependancies. Managing servers and software should be _really_ easy.
* Ability to install and run your own package repository server. Having bespoke configurations and software is sometimes a business requirement
  and sometimes servers do not have direct internet access - making install and deployment needlessly complicated.
  Preferably on open-source webserver software. No DotNet dependencies or third party vendor challenges
* Dependency automation. Installing one package that has dependencies - well, the package manager should handle that for you.
* Self healing. If an install goes awry, self correction should exist.
* Versioning. Packages change and not always for the better. Must have ability to install a specific package version on demand.

#Usage instructions
TODO: Update this doc.
Basically: Create a 'TRANQUIL' directory and place your _control_, postinst, preinst, postrm and prerm scripts here. Run New-TranquilPackage <path/to/your/package> and you're done

