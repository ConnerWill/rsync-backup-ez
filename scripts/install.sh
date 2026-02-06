#!/usr/bin/env bash
# Install script for dynu-ddns updater
set -euo pipefail
IFS=$'\n\t'

# ---------------------------
# CONFIG
# ---------------------------
readonly REPO_ROOT="$(git rev-parse --show-toplevel)"
readonly BIN_DIR="${REPO_ROOT}/bin"
readonly SCRIPT_NAME="rsync-backup-ez"
readonly SCRIPT_PATH="${BIN_DIR}/${SCRIPT_NAME}"
readonly INSTALL_DIR="/usr/local/bin"
readonly INSTALL_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
readonly ZSH_COMPLETION_PATH="${REPO_ROOT}/completion/_${SCRIPT_NAME}"
readonly ZSH_COMPLETION_DEST_PATH="/usr/share/zsh/site-functions/_${SCRIPT_NAME}"
readonly BASH_COMPLETION_PATH="${REPO_ROOT}/completion/${SCRIPT_NAME}_completion.sh"
readonly BASH_COMPLETION_DEST_PATH="/usr/share/bash-completion/completions/${SCRIPT_NAME}"

# ---------------------------
# FUNCTIONS
# ---------------------------
die() {
  printf "❌ %s\n" "${1}" >&2
  exit 1
}

info() {
  printf "ℹ  %s\n" "${1}"
}

success() {
  printf "✅ %s\n" "${1}"
}

require_install() {
  command -v install >/dev/null 2>&1 || die "'install' command not found"
}

require_script() {
  [[ -f "${SCRIPT_PATH}" ]] || die "Script '${SCRIPT_PATH}' not found in '${BIN_DIR}'"
}

# ---------------------------
# MAIN
# ---------------------------
main() {
  require_install
  require_script

  info "Installing '${SCRIPT_NAME}' to '${INSTALL_PATH}'"

  if sudo install -vDm755 "${SCRIPT_NAME}" "${INSTALL_PATH}"; then
    success "'${SCRIPT_NAME}' installed to '${INSTALL_PATH}'"
  else
    die "Unable to install '${SCRIPT_NAME}' to '${INSTALL_PATH}'"
  fi

  ## Zsh completion
  if sudo install -vDm644 "${ZSH_COMPLETION_PATH}" "${ZSH_COMPLETION_DEST_PATH}"; then
    success "Installed zsh completion to '${ZSH_COMPLETION_DEST_PATH}'"
  else
    die "Unable to install zsh completion to '${ZSH_COMPLETION_DEST_PATH}'"
  fi

  ## Bash completion
  if sudo install -vDm644 "${BASH_COMPLETION_PATH}" "${BASH_COMPLETION_DEST_PATH}"; then
    success "Installed bash completion to '${BASH_COMPLETION_DEST_PATH}'"
  else
    die "Unable to install bash completion to '${BASH_COMPLETION_DEST_PATH}'"
  fi
}

main
