#!/usr/bin/env bash

set -Eeuo pipefail

# -------------------------------------------------------------------
# Globals / Defaults (env overrides supported)
# -------------------------------------------------------------------
PROGRAM="${0##*/}"
VERSION="1.0.2"
DESCRIPTION='Back up your home directory (default) or a list of directories to a
remote server using rsync over SSH.'

SSH_BIN="$(command -v ssh)"
RSYNC_BIN="$(command -v rsync)"
DATE_BIN="$(command -v date)"
UNAME_BIN="$(command -v uname)"

# -------------------------------------------------------------------
# Hostname detection (Arch-safe)
# -------------------------------------------------------------------
get_hostname() {
	# 1. systemd (preferred on Arch)
	if command -v hostnamectl >/dev/null 2>&1; then
		hostnamectl --static 2>/dev/null && return 0
	fi

	# 2. /etc/hostname (common fallback)
	if [[ -r /etc/hostname ]]; then
		tr -d ' \t\n' < /etc/hostname && return 0
	fi

	# 3. POSIX fallback
	if [[ -x "${UNAME_BIN}" ]]; then
		"${UNAME_BIN}" -n && return 0
	fi

	return 1
}

LOCAL_HOST="$(get_hostname)" || {
	echo "ERROR: Unable to determine hostname" >&2
	exit 1
}

# ---- Backup target (env > fallback) -------------------------------
REMOTE_USER="${BACKUP_REMOTE_USER:-backup}"
REMOTE_HOST="${BACKUP_REMOTE_HOST:-backup.example.com}"
REMOTE_BASE="${BACKUP_REMOTE_BASE:-/backup}"

REMOTE_DIR="${REMOTE_BASE}/${LOCAL_HOST}"

# ---- SSH key (optional) -------------------------------------------
SSH_KEY="${BACKUP_SSH_KEY:-}"

# ---- Logging ------------------------------------------------------
STATE_BASE="${XDG_STATE_HOME:-${HOME}/.local/state}"
LOG_DIR="${BACKUP_LOG_DIR:-${STATE_BASE}/backup}"
LOG_FILE="${LOG_DIR}/backup.log"

# ---- Runtime flags ------------------------------------------------
DRY_RUN=0
DIRS=()

# -------------------------------------------------------------------
# Logging
# -------------------------------------------------------------------
log_init() {
	mkdir -p "${LOG_DIR}"
	touch "${LOG_FILE}"
}

log() {
	local level current_date
  level="${1}"
	shift
  current_date="$(${DATE_BIN} '+%Y-%m-%d %H:%M:%S')"
	printf "[%s] [%s] %s\n" "${current_date}" "${level}" "${*}" | tee -a "${LOG_FILE}"
}

log_info()  { log "INFO"  "${@}"; }
log_warn()  { log "WARN"  "${@}"; }
log_error() { log "ERROR" "${@}"; }

die() {
	log_error "${*}"
	exit 1
}

# -------------------------------------------------------------------
# Help
# -------------------------------------------------------------------
usage() {
	cat <<EOF
Usage: ${PROGRAM} [OPTIONS]

${DESCRIPTION}

Options:
  --dirs DIR [DIR ...]   Backup specific directories instead of '${HOME}'
  --dry-run              Show what would change without writing
  -h, --help             Show this help message
  -V, --version          Show version

Environment overrides:
  BACKUP_REMOTE_USER     SSH user (default: ${REMOTE_USER})
  BACKUP_REMOTE_HOST     SSH host (default: ${REMOTE_HOST})
  BACKUP_REMOTE_BASE     Remote base directory (default: ${REMOTE_BASE})
  BACKUP_SSH_KEY         Path to SSH private key
  BACKUP_LOG_DIR         Override log directory (default: ${LOG_DIR})

Examples:

  \$ ${PROGRAM}

  \$ BACKUP_SSH_KEY=~/.ssh/backup_ed25519 ${PROGRAM}

  \$ ${PROGRAM} --dirs /etc /opt /srv

Notes:
- Arch Linux compatible (no hostname binary required)
- Designed to run non-interactively (cron-safe)
- SSH key authentication strongly recommended

EOF
}

version() {
  printf "%s %s\n" "${PROGRAM}" "${VERSION}"
}

# -------------------------------------------------------------------
# Argument parsing
# -------------------------------------------------------------------
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--dirs)
				shift
				while [[ $# -gt 0 && "$1" != --* ]]; do
					DIRS+=("$1")
					shift
				done
				;;
			--dry-run)
				DRY_RUN=1
				shift
				;;
			-h|--help)
				usage
				exit 0
				;;
			-V|--version)
			  version
				exit 0
				;;
			*)
				die "Unknown argument: ${1}"
				;;
		esac
	done
}

# -------------------------------------------------------------------
# Excludes
# -------------------------------------------------------------------
rsync_excludes() {
	cat <<'EOF'
--exclude=.cache/
--exclude=.local/share/Trash/
--exclude=.thumbnails/
--exclude=.mozilla/firefox/*/cache2/
--exclude=.config/google-chrome/*/Cache/
--exclude=.config/Code/Cache/
--exclude=.npm/
--exclude=.cargo/registry/
--exclude=.cargo/git/
--exclude=.rustup/
--exclude=.gradle/
--exclude=.m2/repository/
--exclude=node_modules/
--exclude=.venv/
--exclude=__pycache__/
--exclude=*.pyc
--exclude=.git/
--exclude=.svn/
--exclude=.hg/
--exclude=Downloads/
--exclude=.steam/
--exclude=.local/share/Steam/
--exclude=.wine/
--exclude=VirtualBox VMs/
--exclude=.local/share/containers/
EOF
}

# -------------------------------------------------------------------
# Pre-flight checks
# -------------------------------------------------------------------
preflight() {
	[[ -x "${RSYNC_BIN}" ]] || die "rsync not found"
	[[ -x "${SSH_BIN}" ]]   || die "ssh not found"

	if [[ -n "${SSH_KEY}" && ! -r "${SSH_KEY}" ]]; then
		die "SSH key not readable: ${SSH_KEY}"
	fi

	log_info "Local host: ${LOCAL_HOST}"
	log_info "Remote target: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
	[[ -n "${SSH_KEY}" ]] && log_info "Using SSH key: ${SSH_KEY}"
}

# -------------------------------------------------------------------
# Build rsync command
# -------------------------------------------------------------------
build_rsync_cmd() {
	local ssh_cmd="${SSH_BIN} -o BatchMode=yes"

	if [[ -n "${SSH_KEY}" ]]; then
		ssh_cmd+=" -i ${SSH_KEY}"
	fi

	local cmd=(
		"${RSYNC_BIN}"
		--archive
		--numeric-ids
		--hard-links
		--acls
		--xattrs
		--one-file-system
		--delete
		--delete-excluded
		--human-readable
		--stats
		--partial
		--compress
		--timeout=60
		--rsh="${ssh_cmd}"
	)

	if [[ ${DRY_RUN} -eq 1 ]]; then
		cmd+=(--dry-run --itemize-changes)
	fi

	while read -r exclude; do
		cmd+=("${exclude}")
	done < <(rsync_excludes)

	printf "%s\n" "${cmd[@]}"
}

# -------------------------------------------------------------------
# Backup execution
# -------------------------------------------------------------------
run_backup() {
	local sources=()

	if [[ ${#DIRS[@]} -gt 0 ]]; then
		sources=("${DIRS[@]}")
	else
		sources=("${HOME}/")
	fi

	log_info "Backup sources: ${sources[*]}"
	log_info "Starting rsync"

	mapfile -t rsync_cmd < <(build_rsync_cmd)

	"${rsync_cmd[@]}" \
		"${sources[@]}" \
		"${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" \
		>> "${LOG_FILE}" 2>&1

	log_info "Backup completed successfully"
}

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------
main() {
	parse_args "${@}"
	log_init
	preflight
	run_backup
}

main "${@}"
