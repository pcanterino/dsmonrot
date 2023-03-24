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
# This directory MUST exist, it is not created automatically!
[String]$backupDir = "Z:\"
# Disks to backup, see http://www.drivesnapshot.de/en/commandline.htm
[String]$disksToBackup = "HD1:1"
# Path to Drive Snapshot
[String]$dsPath = "C:\Users\Patrick\Desktop\DSMonRot\snapshot.exe"
# Keep backups for this amount of months (excluding the current month),
# -1 for indefinite
[Int32]$keepMonths = 2
# Rotate BEFORE the beginning of a full backup (default is after a successful
# full backup)
# WARNING: If this option is set to $True and the full backup fails you could
# have NO backup
[Boolean]$rotateBeforeBackup = $False
# Set to $True if you want to allow multiple backups for a day
[Boolean]$multipleDailyBackups = $False
# Path to Drive Snapshot log file (specify only the file name if you set
# $dsLogFileToBackup to $True)
#[String]$dsLogFile = "C:\Users\Patrick\Desktop\DSMonRot\snapshot.log"
[String]$dsLogFile = "snapshot.log"
# Set to $True if you want to put the log file of Drive Snapshot into the same
# directory as the backup
[Boolean]$dsLogFileToBackup = $True
# Path to directory where DSMonRot stores the log files
# Every month a new log file is created
[String]$logDir = "$PSScriptRoot\log"
# Keep log files for this amount of months (excluding the current month),
# 0 or less for indefinite
# You should set this to at least the same as $keepMonths
[Int32]$keepLogs = 2
# Comma separated lists of files and directories to exclude from the backup
# See http://www.drivesnapshot.de/en/commandline.htm
# Comment out if you don't want to use it
#[String]$excludedPaths = "Path1,Path2"

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

<# 
.Synopsis 
   Write-Log writes a message to a specified log file with the current time stamp. 
.DESCRIPTION 
   The Write-Log function is designed to add logging capability to other scripts. 
   In addition to writing output and/or verbose you can write to a log file for 
   later debugging. 
.NOTES 
   Created by: Jason Wasser @wasserja 
   Modified: 11/24/2015 09:30:19 AM   
 
   Changelog: 
    * Code simplification and clarification - thanks to @juneb_get_help 
    * Added documentation. 
    * Renamed LogPath parameter to Path to keep it standard - thanks to @JeffHicks 
    * Revised the Force switch to work as it should - thanks to @JeffHicks 
 
   To Do: 
    * Add error handling if trying to create a log file in a inaccessible location. 
    * Add ability to write $Message to $Verbose or $Error pipelines to eliminate 
      duplicates. 
.PARAMETER Message 
   Message is the content that you wish to add to the log file.  
.PARAMETER Path 
   The path to the log file to which you would like to write. By default the function will  
   create the path and file if it does not exist.  
.PARAMETER Level 
   Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational) 
.PARAMETER NoClobber 
   Use NoClobber if you do not wish to overwrite an existing file. 
.EXAMPLE 
   Write-Log -Message 'Log message'  
   Writes the message to c:\Logs\PowerShellLog.log. 
.EXAMPLE 
   Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log 
   Writes the content to the specified log file and creates the path and file specified.  
.EXAMPLE 
   Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error 
   Writes the message to the specified log file as an error message, and writes the message to the error pipeline. 
.LINK 
   https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0 
#>
function Write-Log 
{ 
    [CmdletBinding()] 
    Param 
    ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory=$false)] 
        [Alias('LogPath')] 
        [string]$Path='C:\Logs\PowerShellLog.log', 
         
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
 
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    { 
         
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
            } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
            } 
 
        else { 
            # Nothing to see here yet. 
            } 
 
        # Format Date for our Log File 
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
                } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
                } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
                } 
            } 
         
        # Write log entry to $Path 
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
    } 
    End 
    { 
    } 
}

function Send-Email([String]$body) {
	try {
		# Allow SMTP with SSL and SMTP Auth
		# see: http://petermorrissey.blogspot.de/2013/01/sending-smtp-emails-with-powershell.html
	
		$smtp = New-Object System.Net.Mail.SmtpClient($emailMailServer, $emailPort)

		$smtp.EnableSSL = $emailSSL

		if($emailAuth) {
			$smtp.Credentials = New-Object System.Net.NetworkCredential($emailUser, $emailPassword)
		}

		$smtp.Send($emailFromAddress, $emailToAddress, $emailSubject, $body)
	}
	catch {
		Write-Log "Could not send email: $_.Exception.Message" -Path $logFile -Level Error
	}
}

function Rotate-Backup {
	if($keepMonths -lt 0) {
		return
	}
	
	$keepMonthsCount = $keepMonths
	
	Get-ChildItem $backupDir -Directory | Where-Object {($_.Name -ne $currMonth) -and ($_.Name -match "^\d{4,}-\d{2}$")} | Sort-Object -Descending |
	Foreach-Object {
		if($keepMonthsCount -ge 0) {
			$keepMonthsCount--
		}
		
		if($keepMonthsCount -eq -1) {
			Write-Log "Deleting backup $($_.FullName)" -Path $logFile -Level Info
			Remove-Item -Recurse -Force $_.FullName
		}
	}
}

function Rotate-Log {
	if($keepLogs -le 0) {
		return
	}
	
	$keepLogsCount = $keepLogs
	
	Get-ChildItem $logDir -File | Where-Object {($_.Name -ne "$currMonth.log") -and ($_.Name -match "^\d{4,}-\d{2}\.log$")} | Sort-Object -Descending |
	Foreach-Object {
		if($keepLogsCount -ge 0) {
			$keepLogsCount--
		}
		
		if($keepLogsCount -eq -1) {
			Write-Log "Deleting log file $($_.FullName)" -Path $logFile -Level Info
			Remove-Item -Force $_.FullName
		}
	}
}

$dsAdditionalArgs = @("--UseVSS")

$errorMessages = @()

$smbConnected = $False
$success = $False
$isDiff = $False
$dsCommand = ""

$currMonth = Get-Date -format "yyyy-MM"
$currDay = Get-Date -format "yyyy-MM-dd"
$currTime = Get-Date -format "HH-mm-ss" # no colon because we need this for a directory name

# Check if the directory for the log files exists and create it if necessary
if(!(Test-Path $logDir)) {
	try {
		New-Item -ItemType directory -Path $logDir -ErrorAction Stop | Out-Null
	}
	catch {
		Write-Error "Could not create log directory $logDir`: $_.Exception.Message"
		$errorMessages += "Could not create log directory $logDir`: $_.Exception.Message"
	}
}

$logFile = "$logDir\$currMonth.log"

# Continue only if the log directory exists or if it was created successfully (no error message added)
if($errorMessages.Count -eq 0) {
	$startTime = Get-Date -format "yyyy-MM-dd HH:mm:ss"
	Write-Log "Started at $startTime" -Path $logFile

	# Connect the network drive if necessary
	if($smbDrive) {
		Write-Log "Connecting network drive $smbDrive to $smbPath" -Path $logFile

		try {
			if($smbUser -and $smbPassword) {
				Write-Log "Connecting to network drive with credentials" -Path $logFile
				
				$secSmbPassword = $smbPassword | ConvertTo-SecureString -asPlainText -Force
				$smbCredential = New-Object System.Management.Automation.PSCredential($smbUser, $secSmbPassword)

				New-PSDrive -Name $smbDrive -PSProvider "FileSystem" -Root $smbPath -Credential $smbCredential -Persist -ErrorAction Stop | Out-Null
			}
			else {
				Write-Log "Connecting to network drive without credentials" -Path $logFile
			
				New-PSDrive -Name $smbDrive -PSProvider "FileSystem" -Root $smbPath -Persist -ErrorAction Stop | Out-Null
			}
			
			$smbConnected = $True
		}
		catch {
			Write-Log "Could not connect to network drive $smbDrive`: $_.Exception.Message" -Path $logFile -Level Error
			$errorMessages += "Could not connect to network drive $smbDrive`: $_.Exception.Message"
		}
	}

	# Check if the backup directory exists
	if(!(Test-Path $backupDir)) {
		Write-Log "Directory $backupDir does not exist!" -Path $logFile -Level Error
		$errorMessages += "Directory $backupDir does not exist!"
	}

	# Continue only if no error message was recorded (i.e. backup directory does not exist)
	if($errorMessages.Count -eq 0) {
		# Compose the backup target directories
		$backupTarget = $backupDir + "\" + $currMonth
		$backupTargetFull = $backupTarget + "\Full"

		$backupTargetDiff = $backupTarget + "\Diff-" + $currDay
		
		if($multipleDailyBackups) {
			$backupTargetDiff = $backupTargetDiff + "-" + $currTime
		}

		# Compose the "exclude" parameter if necessary
		if($excludedPaths) {
			$dsAdditionalArgs += "--exclude:" + $excludedPaths
		}

		# Check if the backup target for this month, the directory for the full backup
		# and the hash files exist. In that case we do a differential backup.
		if((Test-Path $backupTarget) -and (Test-Path $backupTargetFull) -and (Test-Path "$backupTargetFull\*.hsh")) {
			# Do a differential backup
		
			Write-Log "Doing a differential backup" -Path $logFile
			
			$isDiff = $True
			
			if(!(Test-Path $backupTargetDiff)) {
				try {
					New-Item -ItemType directory -Path $backupTargetDiff -ErrorAction Stop | Out-Null
				}
				catch {
					Write-Log "Could not create directory $backupTargetDiff`: $_.Exception.Message" -Path $logFile -Level Error
					$errorMessages += "Could not create directory $backupTargetDiff`: $_.Exception.Message"
				}
				
				if($errorMessages.Count -eq 0) {
					$dsLogPath = if($dsLogFileToBackup) { "$backupTargetDiff\$dsLogFile" } else { $dsLogFile }
					
					$dsArgs = @($disksToBackup, "--logfile:$dsLogPath", "$backupTargetDiff\`$disk.sna", "-h$backupTargetFull\`$disk.hsh") + $dsAdditionalArgs
					$dsCommand = "$dsPath $dsArgs"
					
					Write-Log $dsCommand -Path $logFile
					
					& $dsPath $dsArgs
					
					if($LastExitCode -ne 0) {
						Write-Log "Drive Snapshot failed to backup! Exit code: $LastExitCode" -Path $logFile -Level Error
						$errorMessages += "Drive Snapshot failed to backup! Exit code: $LastExitCode"
					}
					else {
						Write-Log "Drive Snapshot succeeded!" -Path $logFile
						$success = $True
					}
				}
			}
			else {
				Write-Log "Directory $backupTargetDiff already exists!" -Path $logFile -Level Error
				$errorMessages += "Directory $backupTargetDiff already exists!"
			}
		}
		else {
			# Do a full backup
		
			Write-Log "Doing a full backup" -Path $logFile

			if(!(Test-Path $backupTarget)) {
				try {
					New-Item -ItemType directory -Path $backupTarget -ErrorAction Stop | Out-Null
				}
				catch {
					Write-Log "Could not create directory $backupTarget`: $_.Exception.Message" -Path $logFile -Level Error
					$errorMessages += "Could not create directory $backupTarget`: $_.Exception.Message"
				}
			}
			
			if($errorMessages.Count -eq 0) {
				if(!(Test-Path $backupTargetFull)) {
					try {
						New-Item -ItemType directory -Path $backupTargetFull -ErrorAction Stop | Out-Null
					}
					catch {
						Write-Log "Could not create directory $backupTargetFull`: $_.Exception.Message" -Path $logFile -Level Error
						$errorMessages += "Could not create directory $backupTargetFull`: $_.Exception.Message"
					}
				}
				
				if($errorMessages.Count -eq 0) {
					if($rotateBeforeBackup) {
						Rotate-Backup
					}
					
					$dsLogPath = if($dsLogFileToBackup) { "$backupTargetFull\$dsLogFile" } else { $dsLogFile }

					$dsArgs = @($disksToBackup, "--logfile:$dsLogPath", "$backupTargetFull\`$disk.sna") + $dsAdditionalArgs
					$dsCommand = "$dsPath $dsArgs"
					
					Write-Log $dsCommand -Path $logFile
					
					& $dsPath $dsArgs
					
					if($LastExitCode -ne 0) {
						Write-Log "Drive Snapshot failed to backup! Exit code: $LastExitCode" -Path $logFile -Level Error
						$errorMessages += "Drive Snapshot failed to backup! Exit code: $LastExitCode"
					}
					else {
						Write-Log "Drive Snapshot succeeded!" -Path $logFile
						$success = $True
					}
					
					if($rotateBeforeBackup -eq $False -and $success -eq $True) {
						Rotate-Backup
					}
				}
			}
		}
	}

	# Disconnect the network drive if necessary
	if($smbConnected) {
		Write-Log "Disconnecting network drive" -Path $logFile
		
		try {
			Remove-PSDrive $smbDrive -ErrorAction Stop
		}
		catch {
			Write-Log "Could not disconnect network drive $smbDrive`: $_.Exception.Message" -Path $logFile -Level Error
			$errorMessages +=  "Could not disconnect network drive $smbDrive`: $_.Exception.Message"
		}
	}
	
	# Rotate the log files
	Rotate-Log
}

# If there was any error message recorded, send a mail if configured
if($emailOnError -and $errorMessages.Count -gt 0) {
	$emailBody  = "This is DSMonRot on $env:computername, started at $startTime.`n"
	$emailBody += "An error occured while performing a backup. Below are the error messages and some status information.`n`n"
	$emailBody += "Backup directory:       $backupDir`n"
	$emailBody += "Log directory:          $logDir`n"
	$emailBody += "Current log file:       $logFile`n"
	$emailBody += "Differential backup:    $isDiff`n"
	$emailBody += "Backup successful:      $success`n"
	$emailBody += "Drive Snapshot command: $dsCommand`n`n"
	$emailBody += ($errorMessages -join "`n")

	Send-Email $emailBody
}

$endTime = Get-Date -format "yyyy-MM-dd HH:mm:ss"
Write-Log "Ended at $endTime" -Path $logFile