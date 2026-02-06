# rsync-backup-ez

A cron-safe Bash script to back up your home directory
*(or a custom list of directories)* to a remote server using `rsync` over SSH.  
Each host backs up into its own directory, automatically named after the local hostname.

## Features

- Uses `rsync` over SSH *(key-based auth recommended)*
- Automatically detects hostname *(Arch Linux–safe)*
- Sensible default excludes *(caches, VCS dirs, build artifacts, downloads, etc.)*
- Supports dry runs
- Logs to an XDG-compliant state directory
- Designed for non-interactive use *(cron/systemd timers)*

## Requirements

- `bash`
- `rsync`
- `ssh`
- SSH access to the remote backup server
