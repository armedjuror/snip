#!/bin/sh
# ─────────────────────────────────────────────
#  snip — shell command aliaser
#  https://github.com/yourusername/snip
# ─────────────────────────────────────────────

SNIP_VERSION="0.0.1"
SNIP_DIR="${HOME}/.snip"

# Detect which shell snip was installed for
# Stored during install so we don't re-detect every run
SNIP_SHELL_FILE="${SNIP_DIR}/.shell"

# ── colours ───────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

_info() { printf "${CYAN}${BOLD}snip${RESET}  %s\n" "$*"; }
_ok()   { printf "${GREEN}✓${RESET} %s\n" "$*"; }
_warn() { printf "${YELLOW}!${RESET} %s\n" "$*"; }
_err()  { printf "${RED}✗${RESET} %s\n" "$*" >&2; }
_dim()  { printf "${DIM}%s${RESET}\n" "$*"; }
_bold() { printf "${BOLD}%s${RESET}\n" "$*"; }
_nl()   { printf "\n"; }

# ── helpers ───────────────────────────────────

_snip_file() {
  if [ -f "${SNIP_SHELL_FILE}" ]; then
    shell=$(cat "${SNIP_SHELL_FILE}")
  else
    # fallback: derive from $SHELL
    shell=$(basename "${SHELL}")
  fi
  printf "%s" "${SNIP_DIR}/snips.${shell}"
}

_ensure_files() {
  mkdir -p "${SNIP_DIR}"
  touch "$(_snip_file)"
}

_editor() {
  if [ -n "${EDITOR}" ]; then
    printf "%s" "${EDITOR}"
  elif command -v nano >/dev/null 2>&1; then
    printf "nano"
  else
    printf "vi"
  fi
}

# Check if a function name exists in the snip file
_exists() {
  grep -q "^${1}()" "$(_snip_file)" 2>/dev/null
}

# Print a named function from the snip file
_get_function() {
  awk "/^${1}\(\)/{found=1} found{print} found && /^\}/{exit}" "$(_snip_file)" 2>/dev/null
}

# Remove a named function from the snip file
_remove_from_file() {
  local name="$1"
  local file
  file="$(_snip_file)"
  local tmp
  tmp="$(mktemp)"
  awk "
    /^${name}\(\)/ { skip=1 }
    skip && /^\}/ { skip=0; next }
    !skip { print }
  " "${file}" > "${tmp}" && mv "${tmp}" "${file}"
}

# Write a function to the snip file
_write_function() {
  local name="$1"
  local body="$2"
  local file
  file="$(_snip_file)"

  _remove_from_file "${name}"
  printf '\n%s() {\n%s\n}\n' "${name}" "${body}" >> "${file}"
}

# Validate function name: letters/digits/_ only, must start with letter or _
_valid_name() {
  case "$1" in
    [a-zA-Z_]*)
      # check rest of string has only valid chars
      rest=$(printf "%s" "$1" | tr -d 'a-zA-Z0-9_-')
      [ -z "${rest}" ]
      ;;
    *) return 1 ;;
  esac
}

_reload_hint() {
  shell=$(cat "${SNIP_SHELL_FILE}" 2>/dev/null || basename "${SHELL}")
  _dim "  Reload your shell:  source ~/.${shell}rc  or open a new tab."
}

# ── commands ──────────────────────────────────

cmd_help() {
  _nl
  _bold "  snip v${SNIP_VERSION} — shell command aliaser"
  _nl
  printf "  ${BOLD}USAGE${RESET}\n"
  printf "    snip <command> [name]\n"
  _nl
  printf "  ${BOLD}COMMANDS${RESET}\n"
  printf "    ${CYAN}add${RESET} <name>       Create a new snip (opens \$EDITOR)\n"
  printf "    ${CYAN}remove${RESET} <name>    Delete a snip\n"
  printf "    ${CYAN}list${RESET}             List all snips\n"
  printf "    ${CYAN}help${RESET}             Show this help\n"
  printf "    ${CYAN}version${RESET}          Show version\n"
  printf "    ${CYAN}uninstall${RESET}        Remove snip from your system\n"
  _nl
  printf "  ${BOLD}ARGUMENT TIPS${RESET}\n"
  _dim "    \$1, \$2 …  positional args        pip install \$1 && pip freeze > requirements.txt"
  _dim "    \"\$@\"       forward all args       git pull \"\$@\""
  _nl
  printf "  ${BOLD}RELOAD${RESET}\n"
  _dim "    After adding/removing snips, reload your shell or open a new tab."
  _nl
}

cmd_version() {
  printf "snip v%s\n" "${SNIP_VERSION}"
}

cmd_add() {
  local name="$1"

  if [ -z "${name}" ]; then
    _err "Usage: snip add <name>"
    return 1
  fi

  if ! _valid_name "${name}"; then
    _err "Invalid name '${name}'. Use letters, numbers, _ or - (must start with a letter or _)."
    return 1
  fi

  _ensure_files

  # Check if already exists
  if _exists "${name}"; then
    _nl
    _warn "Snip '${BOLD}${name}${RESET}${YELLOW}' already exists:${RESET}"
    _nl
    _get_function "${name}" | sed 's/^/    /'
    _nl
    printf "  Overwrite? [y/N] "
    read -r confirm
    case "${confirm}" in
      [Yy]) _nl ;;
      *)
        _info "Aborted."
        return 0
        ;;
    esac
  fi

  _nl
  _bold "  Adding snip: '${name}'"
  _nl
  _dim "  Write the command(s) that '${name}' should run."
  _dim "  Argument tips:"
  _dim "    \$1, \$2 …  positional args  →  pip install \$1"
  _dim "    \"\$@\"       forward all args →  git pull \"\$@\""
  _nl
  _dim "  Your \$EDITOR will open. Save and quit to confirm."
  _nl

  # Temp file with helpful comment header
  local tmpfile
  tmpfile="$(mktemp /tmp/snip_XXXXXX.sh)"

  cat > "${tmpfile}" <<TEMPLATE
# snip: ${name}
# Write the command(s) below. Lines starting with # are ignored.
#
# Examples:
#   git pull "\$@"
#   pip install \$1 && pip freeze > requirements.txt
#   ssh -i ~/.ssh/key.pem ubuntu@1.2.3.4
#
TEMPLATE

  local editor
  editor="$(_editor)"
  "${editor}" "${tmpfile}"

  # Strip comments and blank lines
  local body
  body="$(grep -v '^\s*#' "${tmpfile}" | sed '/^[[:space:]]*$/d')"
  rm -f "${tmpfile}"

  if [ -z "${body}" ]; then
    _warn "Empty body — snip not saved."
    return 1
  fi

  _write_function "${name}" "${body}"

  _nl
  _ok "Snip '${BOLD}${name}${RESET}' saved."
  _reload_hint
  _nl
}

cmd_remove() {
  local name="$1"

  if [ -z "${name}" ]; then
    _err "Usage: snip remove <name>"
    return 1
  fi

  _ensure_files

  if ! _exists "${name}"; then
    _err "No snip named '${name}' found."
    return 1
  fi

  _nl
  _warn "About to remove snip '${BOLD}${name}${RESET}${YELLOW}':${RESET}"
  _nl
  _get_function "${name}" | sed 's/^/    /'
  _nl
  printf "  Confirm removal? [y/N] "
  read -r confirm
  case "${confirm}" in
    [Yy]) ;;
    *)
      _info "Aborted."
      return 0
      ;;
  esac

  _remove_from_file "${name}"

  _nl
  _ok "Snip '${name}' removed."
  _reload_hint
  _nl
}

cmd_list() {
  _ensure_files

  local file
  file="$(_snip_file)"

  local names
  names=$(grep '^[a-zA-Z_][a-zA-Z0-9_-]*()'  "${file}" 2>/dev/null | sed 's/().*//')

  if [ -z "${names}" ]; then
    _nl
    _dim "  No snips yet. Add one with:  snip add <name>"
    _nl
    return 0
  fi

  _nl
  _bold "  Saved snips:"
  _nl

  printf "%s\n" "${names}" | while IFS= read -r name; do
    [ -z "${name}" ] && continue
    printf "  ${CYAN}${BOLD}%s${RESET}\n" "${name}"
    # Print body only (strip first and last line of function wrapper)
    _get_function "${name}" | tail -n +2 | head -n -1 | sed 's/^/    /'
    _nl
  done
}

cmd_uninstall() {
  _nl
  _warn "This will:"
  printf "    • Remove %s\n" "${SNIP_DIR}"
  printf "    • Remove the snip source line from your rc file\n"
  _nl
  printf "  Are you sure? [y/N] "
  read -r confirm
  case "${confirm}" in
    [Yy]) ;;
    *)
      _info "Aborted."
      return 0
      ;;
  esac

  local shell
  shell=$(cat "${SNIP_SHELL_FILE}" 2>/dev/null || basename "${SHELL}")
  local rc="${HOME}/.${shell}rc"

  if [ -f "${rc}" ]; then
    local tmp
    tmp="$(mktemp)"
    grep -v '# snip managed' "${rc}" > "${tmp}" && mv "${tmp}" "${rc}"
    _ok "Cleaned ${rc}"
  fi

  rm -rf "${SNIP_DIR}"
  _ok "Removed ${SNIP_DIR}"
  _nl
  _bold "  snip uninstalled. Reload your shell."
  _nl
}

# ── entrypoint ────────────────────────────────

main() {
  cmd="${1:-}"
  shift 2>/dev/null || true

  case "${cmd}" in
    add)              cmd_add "$@" ;;
    remove|rm)        cmd_remove "$@" ;;
    list|ls)          cmd_list ;;
    version|-v)       cmd_version ;;
    uninstall)        cmd_uninstall ;;
    help|-h|--help|"") cmd_help ;;
    *)
      _err "Unknown command '${cmd}'. Run 'snip help' for usage."
      exit 1
      ;;
  esac
}

main "$@"
