# DSMonRot
# Script for rotating Drive Snapshot backups monthly
#
# Author: Patrick Canterino <patrick@patrick-canterino.de>
# WWW: https://www.patrick-canterino.de/
#      https://github.com/pcanterino/dsmonrot
# License: 2-Clause BSD License
#
# Drive Snapshot is copyright by Tom Ehlert
# http://www.drivesnapshot.de/

# Config

# Path to backup directory
[String]$backupDir = "Z:\"
# Keep backup for this amount of months (excluding the current month),
# -1 for indefinite
[Int32]$keepMonths = 2
# Rotate BEFORE the beginning of a full backup (default is after a successful
# full backup)
# WARNING: If this option is set to $True and the full backup fails you could
# have NO backup
$rotateBeforeBackup = $False
# Path to Drive Snapshot
[String]$dsPath = "C:\Users\Patrick\Desktop\DSMonRot\snapshot.exe"
# Path to Drive Snapshot log file (specify only the file name if you set
# $dsLogFileToBackup to $True)
#[String]$dsLogFile = "C:\Users\Patrick\Desktop\DSMonRot\snapshot.log"
[String]$dsLogFile = "snapshot.log"
# Set to $True if you want to put the log file of Drive Snapshot into the same
# directory as the backup
[Boolean]$dsLogFileToBackup = $True
# Disks to backup, see http://www.drivesnapshot.de/en/commandline.htm
[String]$disksToBackup = "HD1:1"
# Path to DSMonRot log file
[String]$logFile = "C:\Users\Patrick\Desktop\DSMonRot\dsmonrot.log"

# Map network share to this drive letter, comment out if you don't want to use it
[String]$smbDrive = "Z"
# Path to network share
[String]$smbPath = "\\192.168.0.3\ds"
# User and password for connecting to network share, comment out if you don't want to use it
# (for example if you want to pass current Windows credentials)
[String]$smbUser = "patrick"
[String]$smbPassword = ""

# Send an email if an error occured
[Boolean]$emailOnError = $True
# From address of email notification
[String]$emailFromAddress = "alarm@test.local"
# To address of email notification
[String]$emailToAddress = "patrick@test.local"
# Subject of email notification
[String]$emailSubject = "DSMonRot on $env:computername"
# Mail server
[String]$emailMailserver = "localhost"
# SMTP Port
[Int32]$emailPort = 25
# Use SSL?
[Boolean]$emailSSL = $False
# Use SMTP Auth?
[Boolean]$emailAuth = $False
# SMTP Auth User
[String]$emailUser = ""
# SMTP Auth Password
[String]$emailPassword = ""

# End of config

$dsAdditionalArgs = @("--UseVSS")

# Allow SMTP with SSL and SMTP Auth
# see: http://petermorrissey.blogspot.de/2013/01/sending-smtp-emails-with-powershell.html
function Send-Email([String]$body) {
	Write-Host "Sending email: $emailToAddress, $body"
	
	try {
		$smtp = New-Object System.Net.Mail.SmtpClient($emailMailServer, $emailPort)

		$smtp.EnableSSL = $emailSSL

		if($emailAuth) {
			$smtp.Credentials = New-Object System.Net.NetworkCredential($emailUser, $emailPassword)
		}

		$smtp.Send($emailFromAddress, $emailToAddress, $emailSubject, $body)
	}
	catch {
		Write-Host "Could not send email: $_.Exception.Message"
	}
}

function Rotate-Backup {
	if($keepMonths -lt 0) {
		return
	}

	Write-Host "Rotating"
	
	$keepMonthsCount = $keepMonths
	
	Get-ChildItem $backupDir -Directory | Where-Object {($_.Name -ne $currMonth) -and ($_.Name -match "^\d{4,}-\d{2}$")} | Sort-Object -Descending |
	Foreach-Object {
		Write-Host $_ "=>" $_.FullName
		
		if($keepMonthsCount -ge 0) {
			$keepMonthsCount--
		}
		
		if($keepMonthsCount -eq -1) {
			Write-Host "Deleting $_"
			Remove-Item -Recurse -Force $_.FullName
		}
	}
}

$startTime = Get-Date -format "yyyy-MM-dd HH:mm:ss"
Write-Host "Started at $startTime"

$errorMessages = @()

$smbConnected = $False
$success = $False
$isDiff = $False
$dsCommand = ""

if($smbDrive) {
	try {
		Write-Host "Connecting network drive"
		
		if($smbUser -and $smbPassword) {
			Write-Host "With credentials"
			
			$secSmbPassword = $smbPassword | ConvertTo-SecureString -asPlainText -Force
			$smbCredential = New-Object System.Management.Automation.PSCredential($smbUser, $secSmbPassword)

			New-PSDrive -Name $smbDrive -PSProvider "FileSystem" -Root $smbPath -Credential $smbCredential -Persist -ErrorAction Stop | Out-Null
		}
		else {
			Write-Host "Without credentials"
		
			New-PSDrive -Name $smbDrive -PSProvider "FileSystem" -Root $smbPath -Persist -ErrorAction Stop | Out-Null
		}
		
		$smbConnected = $True
	}
	catch {
		Write-Host "Could not connect to network drive $smbDrive`: $_.Exception.Message"
		$errorMessages += "Could not connect to network drive $smbDrive`: $_.Exception.Message"
	}
}

if(!(Test-Path $backupDir)) {
	Write-Host "Directory $backupDir does not exist!"
	$errorMessages += "Directory $backupDir does not exist!"
}

if($errorMessages.Count -eq 0) {
	$currMonth = Get-Date -format "yyyy-MM"
	$currDay = Get-Date -format "yyyy-MM-dd"

	Write-Host $currMonth

	$backupTarget = $backupDir + "\" + $currMonth
	$backupTargetFull = $backupTarget + "\" + "Full"

	$backupTargetDiff = $backupTarget + "\" + "Diff-" + $currDay

	Write-Host $backupTarget

	if((Test-Path $backupTarget) -and (Test-Path $backupTargetFull) -and (Test-Path "$backupTargetFull\*.hsh")) {
		Write-Host "Differential backup"
		
		$isDiff = $True
		
		if(!(Test-Path $backupTargetDiff)) {
			Write-Host "Creating directory $backupTargetDiff"
			
			try {
				New-Item -ItemType directory -Path $backupTargetDiff -ErrorAction Stop | Out-Null
			}
			catch {
				Write-Host "Could not create directory $backupTargetDiff`: $_.Exception.Message"
				$errorMessages += "Could not create directory $backupTargetDiff`: $_.Exception.Message"
			}
			
			if($errorMessages.Count -eq 0) {
				$dsLogPath = if($dsLogFileToBackup) { "$backupTargetDiff\$dsLogFile" } else { $dsLogFile }
				
				$dsArgs = @($disksToBackup, "--logfile:$dsLogPath", "$backupTargetDiff\`$disk.sna", "-h$backupTargetFull\`$disk.hsh") + $dsAdditionalArgs
				Write-Host $dsPath ($dsArgs -join " ")
				
				$dsCommand = "$dsPath $dsArgs"
				
				& $dsPath $dsArgs
				
				if($LastExitCode -ne 0) {
					Write-Host "Drive Snapshot failed to backup! Exit code: $LastExitCode"
					$errorMessages += "Drive Snapshot failed to backup! Exit code: $LastExitCode"
				}
				else {
					$success = $True
				}
			}
		}
		else {
			Write-Host "Directory $backupTargetDiff already exists!"
			$errorMessages += "Directory $backupTargetDiff already exists!"
		}
	}
	else {
		Write-Host "Full backup"

		if(!(Test-Path $backupTarget)) {
			Write-Host "Creating directory $backupTarget"
			
			try {
				New-Item -ItemType directory -Path $backupTarget -ErrorAction Stop | Out-Null
			}
			catch {
				Write-Host "Could not create directory $backupTarget`: $_.Exception.Message"
				$errorMessages += "Could not create directory $backupTarget`: $_.Exception.Message"
			}
		}
		
		if($errorMessages.Count -eq 0) {
			if(!(Test-Path $backupTargetFull)) {
				Write-Host "Creating directory $backupTargetFull"
				
				try {
					New-Item -ItemType directory -Path $backupTargetFull -ErrorAction Stop | Out-Null
				}
				catch {
					Write-Host "Could not create directory $backupTargetFull`: $_.Exception.Message"
					$errorMessages += "Could not create directory $backupTargetFull`: $_.Exception.Message"
				}
			}
			
			if($errorMessages.Count -eq 0) {
				if($rotateBeforeBackup) {
					Rotate-Backup
				}
				
				$dsLogPath = if($dsLogFileToBackup) { "$backupTargetFull\$dsLogFile" } else { $dsLogFile }

				$dsArgs = @($disksToBackup, "--logfile:$dsLogPath", "$backupTargetFull\`$disk.sna") + $dsAdditionalArgs
				Write-Host $dsPath ($dsArgs -join " ")
				
				$dsCommand = "$dsPath $dsArgs"
				
				& $dsPath $dsArgs
				
				if($LastExitCode -ne 0) {
					Write-Host "Drive Snapshot failed to backup! Exit code: $LastExitCode"
					$errorMessages += "Drive Snapshot failed to backup! Exit code: $LastExitCode"
				}
				else {
					$success = $True
				}
				
				if($rotateBeforeBackup -eq $False -and $success -eq $True) {
					Rotate-Backup
				}
			}
		}
	}
}

if($smbConnected) {
	Write-Host "Disconnecting network drive"
	
	try {
		Remove-PSDrive $smbDrive -ErrorAction Stop
	}
	catch {
		Write-Host "Could not disconnect network drive $smbDrive`: $_.Exception.Message"
		$errorMessages +=  "Could not disconnect network drive $smbDrive`: $_.Exception.Message"
	}
}

if($emailOnError -and $errorMessages.Count -gt 0) {
	$emailBody  = "This is DSMonRot on $env:computername, started at $startTime.`n"
	$emailBody += "An error occured while performing a backup. Below are the error messages and some status information.`n`n"
	$emailBody += "Backup directory:       $backupDir`n"
	$emailBody += "Differential backup:    $isDiff`n"
	$emailBody += "Backup successful:      $success`n"
	$emailBody += "Drive Snapshot command: $dsCommand`n`n"
	$emailBody += ($errorMessages -join "`n")

	Send-Email ($emailBody)
}

$endTime = Get-Date -format "yyyy-MM-dd HH:mm:ss"
Write-Host "Ended at $endTime"