#!/bin/sh
# ─────────────────────────────────────────────
#  snip installer — POSIX sh
#  curl -fsSL https://raw.githubusercontent.com/armedjuror/snip/main/install.sh | bash
# ─────────────────────────────────────────────

set -e

SNIP_REPO="https://raw.githubusercontent.com/armedjuror/snip/main"
SNIP_DIR="${HOME}/.snip"
SNIP_BIN="${SNIP_DIR}/snip.sh"
SNIP_SHELL_FILE="${SNIP_DIR}/.shell"
LOCAL_BIN="${HOME}/.local/bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

_ok()   { printf "${GREEN}✓${RESET} %s\n" "$*"; }
_info() { printf "${CYAN}▸${RESET} %s\n" "$*"; }
_err()  { printf "${RED}✗${RESET} %s\n" "$*" >&2; exit 1; }
_dim()  { printf "${DIM}%s${RESET}\n" "$*"; }
_bold() { printf "${BOLD}%s${RESET}\n" "$*"; }
_nl()   { printf "\n"; }

# ── detect shell ──────────────────────────────

detect_shell() {
  # $SHELL is set by the OS to the user's login shell.
  # Even though this script runs in bash (via curl|bash),
  # $SHELL correctly reflects the user's actual shell.
  if [ -z "${SHELL}" ]; then
    _err "Could not detect shell: \$SHELL is not set."
  fi

  detected=$(basename "${SHELL}")

  case "${detected}" in
    zsh|bash) printf "%s" "${detected}" ;;
    *)
      # Unknown shell — ask the user
      printf "${CYAN}▸${RESET} Could not detect shell (got: %s).\n" "${detected}"
      printf "  Enter your shell (zsh/bash): "
      read -r input
      case "${input}" in
        zsh|bash) printf "%s" "${input}" ;;
        *) _err "Unsupported shell '${input}'. snip supports zsh and bash." ;;
      esac
      ;;
  esac
}

# ── steps ─────────────────────────────────────

step_download() {
  _info "Downloading snip..."
  mkdir -p "${SNIP_DIR}"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${SNIP_REPO}/snip.sh" -o "${SNIP_BIN}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${SNIP_BIN}" "${SNIP_REPO}/snip.sh"
  else
    _err "Neither curl nor wget found. Please install one and retry."
  fi

  chmod +x "${SNIP_BIN}"
  _ok "Downloaded snip.sh → ${SNIP_BIN}"
}

step_create_snip_file() {
  local shell="$1"
  local snip_file="${SNIP_DIR}/snips.${shell}"
  touch "${snip_file}"
  # Save detected shell for snip.sh to read later
  printf "%s" "${shell}" > "${SNIP_SHELL_FILE}"
  _ok "Created ${snip_file}"
}

step_add_to_path() {
  mkdir -p "${LOCAL_BIN}"
  # Write a tiny wrapper so 'snip' works as a command
  cat > "${LOCAL_BIN}/snip" <<EOF
#!/bin/sh
exec "${SNIP_BIN}" "\$@"
EOF
  chmod +x "${LOCAL_BIN}/snip"
  _ok "Installed snip command → ${LOCAL_BIN}/snip"
}

step_wire_rc() {
  local shell="$1"
  local rc="${HOME}/.${shell}rc"
  local snip_file="${SNIP_DIR}/snips.${shell}"

  # Create rc file if it doesn't exist
  if [ ! -f "${rc}" ]; then
    touch "${rc}"
    _info "Created ${rc}"
  fi

  # Add snip file source line (idempotent)
  if grep -q '# snip managed' "${rc}" 2>/dev/null; then
    _ok "${rc} already configured — skipping"
  else
    printf '\n# snip — shell command aliaser\n' >> "${rc}"
    printf '[ -f "%s" ] && . "%s" # snip managed\n' "${snip_file}" "${snip_file}" >> "${rc}"
    _ok "Added source line to ${rc}"
  fi

  # Ensure ~/.local/bin is on PATH (idempotent)
  if ! grep -q '.local/bin' "${rc}" 2>/dev/null; then
    printf '\nexport PATH="%s:${PATH}" # snip managed\n' "${LOCAL_BIN}" >> "${rc}"
    _ok "Added ${LOCAL_BIN} to PATH in ${rc}"
  fi
}

# ── main ──────────────────────────────────────

_nl
_bold "  Installing snip..."
_nl

SNIP_SHELL=$(detect_shell)
_info "Detected shell: ${SNIP_SHELL}"
_nl

step_download
step_create_snip_file "${SNIP_SHELL}"
step_add_to_path
step_wire_rc "${SNIP_SHELL}"

_nl
installed_version=$(grep '^SNIP_VERSION=' "${SNIP_BIN}" | head -1 | sed 's/SNIP_VERSION="//;s/"//')
_bold "  ✓ snip v${installed_version} installed!"
_nl
_dim "  Snips file : ${SNIP_DIR}/snips.${SNIP_SHELL}"
_dim "  Binary     : ${LOCAL_BIN}/snip"
_nl
printf "  ${BOLD}Reload your shell:${RESET}\n"
_dim "    source ${HOME}/.${SNIP_SHELL}rc"
_nl
printf "  ${BOLD}Then try:${RESET}  snip help\n"
_nl
