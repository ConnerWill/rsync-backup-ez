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

require_script() {
  [[ -f "${INSTALL_PATH}" ]] || die "Script '${SCRIPT_NAME}' not found in '${INSTALL_PATH}'"
}

# ---------------------------
# MAIN
# ---------------------------
main() {
  require_script

  info "Uninstalling ${SCRIPT_NAME} from ${INSTALL_PATH}"

  if [[ -e "${INSTALL_PATH}" ]]; then
    sudo rm -f "${INSTALL_PATH}" || { info "Unable to remove '${SCRIPT_NAME}' from '${INSTALL_PATH}'"; }
  else
    info "Cannot find '${SCRIPT_NAME}' at location: '${INSTALL_PATH}'"
  fi

  if [[ -e "${ZSH_COMPLETION_DEST_PATH}" ]]; then
    info "Removing zsh completion: '${ZSH_COMPLETION_DEST_PATH}'"
    sudo rm -f "${ZSH_COMPLETION_DEST_PATH}" || { info "Unable to remove zsh completion file: '${ZSH_COMPLETION_DEST_PATH}'"; }
  else
    info "Cannot find zsh completion file: '${ZSH_COMPLETION_DEST_PATH}'"
  fi

  if [[ -e "${BASH_COMPLETION_DEST_PATH}" ]]; then
    info "Removing bash completion: '${BASH_COMPLETION_DEST_PATH}'"
    sudo rm -f "${BASH_COMPLETION_DEST_PATH}" || { info "Unable to remove bash completion file: '${BASH_COMPLETION_DEST_PATH}'"; }
  else
    info "Cannot find bash completion file: '${BASH_COMPLETION_DEST_PATH}'"
  fi
}

main
