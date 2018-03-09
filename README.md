# DSMonRot

DSMonRot is a script for rotating Drive Snapshot backups monthly (DSMonRot stands for **D**rive **S**napshot **Mon**thly **Rot**ate).

It's main purpose is to create a full backup at the beginning and then create differential backups for the rest of the month. Furthermore it rotates the backups after every successful full backup allowing you to keep only a certain amount of monthly backup sets.

## Installation

TODO

## Credits

* DSMonRot: Patrick Canterino, https://www.patrick-canterino.de/
* Drive Snapshot: Tom Ehlert, http://www.drivesnapshot.de/
* Logging function (``Write-Log``): Jason Wasser, https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0 