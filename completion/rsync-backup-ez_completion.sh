#!/usr/bin/env bash

# rsync-backup-ez - bash completion

_rsync-backup-ez_complete() {
    local cur prev words cword
    _init_completion || return

    COMPREPLY=()

    # Complete --long-options
    if [[ ${cur} == --* ]]; then
        COMPREPLY=( $(compgen -W "--dirs --dry-run --help --version" -- "${cur}") )
        return
    fi

    # Complete -short options
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "-d -h -V" -- "${cur}") )
        return
    fi

    # If we're at position 1 (first word after command) → show options only
    if (( cword == 1 )); then
        local opts="-d --dirs --dry-run -h --help -V --version"
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi

    # After any recognized option → nothing more
    case "${prev}" in
        -d|--dirs|--dry-run|-h|--help|-V|--version)
            return 0
            ;;
    esac

    # Fallback: nothing
    return 0
}

complete -F _rsync-backup-ez_complete rsync-backup-ez
