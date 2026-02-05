#!/usr/bin/env bash

set -Eeuo pipefail

# -------------------------------------------------------------------
# Globals / Defaults (env overrides supported)
# -------------------------------------------------------------------
PROGRAM="${0##*/}"
VERSION="1.1"

SSH_BIN="/usr/bin/ssh"
RSYNC_BIN="/usr/bin/rsync"
DATE_BIN="/usr/bin/date"
HOSTNAME_BIN="/usr/bin/hostname"

LOCAL_HOST="$(${HOSTNAME_BIN} -s)"

# ---- Backup target (env > fallback) -------------------------------
REMOTE_USER="${BACKUP_REMOTE_USER:-backup-host1}"
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
	local level="${1}"
	shift
	printf "[%s] [%s] %s\n" \
		"$(${DATE_BIN} '+%Y-%m-%d %H:%M:%S')" \
		"${level}" \
		"${*}" | tee -a "${LOG_FILE}"
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

Back up your home directory (default) or a list of directories to a
remote server using rsync over SSH.

Options:
  --dirs DIR [DIR ...]   Backup specific directories instead of '${HOME}'
  --dry-run              Show what would change without writing
  -h, --help             Show this help message

Environment overrides:
  BACKUP_REMOTE_USER     SSH user (default: backup-host1)
  BACKUP_REMOTE_HOST     SSH host
  BACKUP_REMOTE_BASE     Remote base directory (default: /backup)
  BACKUP_SSH_KEY         Path to SSH private key
  BACKUP_LOG_DIR         Override log directory

Examples:
  backup.sh
  BACKUP_SSH_KEY=~/.ssh/backup_ed25519 backup.sh
  backup.sh --dirs /etc /opt /srv

Notes:
- Designed to run non-interactively (cron-safe)
- SSH key authentication strongly recommended
- Logs stored under '\$XDG_STATE_HOME' or '\$HOME/.local/state'
EOF
}

# -------------------------------------------------------------------
# Argument parsing
# -------------------------------------------------------------------
parse_args() {
	while [[ ${#} -gt 0 ]]; do
		case "${1}" in
			--dirs)
				shift
				while [[ ${#} -gt 0 && "${1}" != --* ]]; do
					DIRS+=("${1}")
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
