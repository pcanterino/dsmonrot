# TODO

- [x] Collect error messages and send them via email
- [x] Check if directories are created successfully
- [x] ~~Check if the network drive already exists before connecting~~ ⇒ `New-PSDrive` throws an exception if drive is already connected
- [x] Create a log file for the script
- [x] Clean up the messages sent to the console or send them to the debug or error streams (e.g. `Write-Debug` or `Write-Error`)
- [x] Rotate log files
- [x] Suppress output of some commands
- [ ] Add some comments to the source code
- [x] Allow multiple backups for a day