#Tranquil Package Manager
For managing custom bespoke packages on Windows servers

##What is Tranquil and Why build it
Administrating custom scripts and applications for Windows Servers often require building and deploying these scripts onto the server itself.
I've found that creating .msi or .exe packages can be quite tedious and requires heavy .net frameworks or compiling .dll files. 
This in turn requires software to create and manage these packages. All of this is a heavy operational overhead.

I wanted to create a package manager that is extremely light-weight and uses _only_ built-in functions and features in the Windows operating system.
For this, I use PowerShell. There might be one exception to this rule, and that is package signing for which I was thinking to use opengpg - but I haven't started that codebase yet... Maybe I'll find a built-in PowerShell function that supports gpg/pgp.

Tranquil is built on the DEBIAN (.deb) package manager build process.

#Usage instructions
TODO: Update this doc.
Basically: Create a 'TRANQUIL' directory and place your _control_, postinst, preinst, postrm and prerm scripts here. Run New-TranquilPackage <path/to/your/package> and you're done

