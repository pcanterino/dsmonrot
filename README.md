# DSMonRot

DSMonRot is a script for rotating [Drive Snapshot](http://www.drivesnapshot.de/) backups monthly (DSMonRot stands for **D**rive **S**napshot **Mon**thly **Rot**ate).

It's main purpose is to create a full backup at the beginning and then create differential backups for the rest of the month. Furthermore it rotates the backups after every successful full backup allowing you to keep only a certain amount of monthly backup sets. DSMonRot creates monthly log files allowing you to check for success or errors.

## Requirements

* PowerShell 4.0 (or higher)
* [Drive Snapshot](http://www.drivesnapshot.de/) (tested with version 1.45)

## Basic installation

1. Copy *dsmonrot.ps1* to arbitrary directory (for example *C:\DSMonRot*). You should also sign this script file or set PowerShell execution policy to *Unrestricted*.
2. Download Drive Snapshot from http://www.drivesnapshot.de/ and copy it to the directory mentioned in the step above
3. Create a directory for your backups (for example *D:\Backup*)
4. Edit *dsmonrot.ps1* and edit the following variables:
    1. Set ``$backupDir`` to the path you created in step 3
    2. Specify the disks and partitions you want to backup in ``$disksToBackup``, see http://www.drivesnapshot.de/en/commandline.htm for syntax
    3. Adjust ``$dsPath`` to point to the path of Drive Snapshot (for example *C:\DSMonRot\snapshot.exe*)
    4. Specify the number of months to keep the backups by adjusting ``$keepMonths`` (the current month does not count, so if you set this variable to ``2``, DSMonRot keeps the current month **and** the last two months), set to ``0`` if you only want to keep the current month, set to ``-1`` if you don't want to delete any backup (not recommended)
    5. After adjusting ``$keepMonths``, you should also adjust ``$keepLogs`` to at least the same amount. This variable controls the number of log files, DSMonRot keeps.
    5. If your backup directory is on a SMB share, you have to edit the variables ``$smbDrive``, ``$smbPath``, ``$smbUser`` and ``$smbPassword``
    6. If you want DSMonRot to send a mail if an error occuris, you have to edit the variables ``$emailOnError``, ``$emailFromAddress``, ``$emailToAddress``, ``$emailSubject``, ``$emailMailserver``, ``$emailPort``, ``$emailSSL``, ``$emailAuth``, ``$emailUser`` and ``$emailPassword``
    7. If you want to adjust more configuration variables, just have a look at the comments preceeding each variable.
5. Configure Windows task planner to execute your script

## Credits

* DSMonRot: Patrick Canterino, https://www.patrick-canterino.de/
* Drive Snapshot: Tom Ehlert, http://www.drivesnapshot.de/
* Logging function (``Write-Log``): Jason Wasser, https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0 