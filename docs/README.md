# rsync-backup-ez

A cron-safe Bash script to back up your home directory
*(or a custom list of directories)* to a remote server using `rsync` over SSH.
Each host backs up into its own directory, automatically named after the local hostname.

## Table of Contents

<!--toc:start-->
- [rsync-backup-ez](#rsync-backup-ez)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Requirements](#requirements)
  - [Installation](#installation)
    - [Installation Script](#installation-script)
    - [Manual Installation](#manual-installation)
  - [Uninstallation](#uninstallation)
    - [Uninstallation Script](#uninstallation-script)
    - [Manual Uninstallation](#manual-uninstallation)
<!--toc:end-->

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

## Installation

### Installation Script

```sh
./scripts/install.sh
```

### Manual Installation

Install `rsync-backup-ez`

```sh
sudo install -vDm755 "bin/rsync-backup-ez" "/usr/local/bin/rsync-backup-ez"
```

Install `rsync-backup-ez` shell completion

```sh
## Zsh completion
sudo install -vDm644 "completion/_rsync-backup-ez" "/usr/share/zsh/site-functions/_rsync-backup-ez"

## Bash completion
sudo install -vDm644 "completion/rsync-backup-ez_completion.sh" "/usr/share/bash-completion/completions/rsync-backup-ez"
```

## Uninstallation

### Uninstallation Script

```sh
./scripts/uninstall.sh
```

### Manual Uninstallation

Remove `rsync-backup-ez`

```sh
sudo rm -fv "/usr/local/bin/rsync-backup-ez"
```

Remove `rsync-backup-ez` shell completion

```sh
## Zsh completion
sudo rm -fv "/usr/share/zsh/site-functions/_rsync-backup-ez"

## Bash completion
sudo rm -fv  "/usr/share/bash-completion/completions/rsync-backup-ez"
```
