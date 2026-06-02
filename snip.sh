#!/bin/sh
# ─────────────────────────────────────────────
#  snip — shell command aliaser
#  https://github.com/armedjuror/snip
# ─────────────────────────────────────────────

SNIP_VERSION="0.0.5"
SNIP_REPO="https://raw.githubusercontent.com/armedjuror/snip/main"
SNIP_DIR="${HOME}/.snip"
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

_detected_shell() {
  if [ -f "${SNIP_SHELL_FILE}" ]; then
    cat "${SNIP_SHELL_FILE}"
  else
    basename "${SHELL}"
  fi
}

_snip_file() {
  printf "%s/snips.%s" "${SNIP_DIR}" "$(_detected_shell)"
}

_ensure_files() {
  mkdir -p "${SNIP_DIR}"
  touch "$(_snip_file)"
}

_editor() {
  if [ -n "${EDITOR}" ]; then
    printf "%s" "${EDITOR}"
  elif command -v vim >/dev/null 2>&1; then
    printf "vim"
  elif command -v vi >/dev/null 2>&1; then
    printf "vi"
  else
    printf "nano"
  fi
}

_exists() {
  grep -q "^${1}()" "$(_snip_file)" 2>/dev/null
}

_get_function() {
  awk "/^${1}\(\)/{found=1} found{print} found && /^\}/{exit}" "$(_snip_file)" 2>/dev/null
}

_remove_from_file() {
  local name="$1"
  local file tmp
  file="$(_snip_file)"
  tmp="$(mktemp)"
  awk "
    /^${name}\(\)/ { skip=1 }
    skip && /^\}/ { skip=0; next }
    !skip { print }
  " "${file}" > "${tmp}" && mv "${tmp}" "${file}"
}

_write_function() {
  local name="$1"
  local body="$2"
  local file
  file="$(_snip_file)"
  _remove_from_file "${name}"
  printf '\n%s() {\n%s\n}\n' "${name}" "${body}" >> "${file}"
}

_valid_name() {
  case "$1" in
    [a-zA-Z_]*)
      rest=$(printf "%s" "$1" | tr -d 'a-zA-Z0-9_-')
      [ -z "${rest}" ]
      ;;
    *) return 1 ;;
  esac
}

# Print a prominent reload hint — child processes can't source the parent
# shell, so we show the exact command for the user to run themselves.
_reload_hint() {
  local shell rc
  shell="$(_detected_shell)"
  rc="${HOME}/.${shell}rc"
  _nl
  printf "  ${DIM}To apply, run:${RESET}\n"
  _nl
  printf "  ${BOLD}  source %s${RESET}\n" "${rc}"
  _nl
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
  printf "    ${CYAN}add${RESET} <name>            Create a new snip (opens \$EDITOR)\n"
  printf "    ${CYAN}edit${RESET} <name>           Edit an existing snip\n"
  printf "    ${CYAN}rename${RESET} <name> <new>   Rename a snip\n"
  printf "    ${CYAN}remove${RESET} <name>         Delete a snip\n"
  printf "    ${CYAN}list${RESET}             List all snips\n"
  printf "    ${CYAN}export${RESET}           Print all snips for copying\n"
  printf "    ${CYAN}import${RESET}           Import snips from another machine\n"
  printf "    ${CYAN}upgrade${RESET}          Upgrade snip to the latest version\n"
  printf "    ${CYAN}version${RESET}          Show installed version\n"
  printf "    ${CYAN}uninstall${RESET}        Remove snip from your system\n"
  printf "    ${CYAN}help${RESET}             Show this help\n"
  _nl
  printf "  ${BOLD}ARGUMENT TIPS${RESET}\n"
  _dim "    \$1, \$2 …  positional args  →  pip install \$1 && pip freeze > requirements.txt"
  _dim "    \"\$@\"       forward all args →  git pull \"\$@\""
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

  # If already exists, show current definition and confirm overwrite
  if _exists "${name}"; then
    _nl
    printf "${YELLOW}!${RESET} Snip '${BOLD}%s${RESET}${YELLOW}' already exists:${RESET}\n" "${name}"
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
  printf "${GREEN}✓${RESET} Snip '${BOLD}%s${RESET}' saved.\n" "${name}"
  _reload_hint
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
  printf "${YELLOW}!${RESET} About to remove snip '${BOLD}%s${RESET}${YELLOW}':${RESET}\n" "${name}"
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
}

cmd_rename() {
  local name="$1"
  local newname="$2"

  if [ -z "${name}" ] || [ -z "${newname}" ]; then
    _err "Usage: snip rename <name> <new-name>"
    return 1
  fi

  if ! _valid_name "${newname}"; then
    _err "Invalid name '${newname}'. Use letters, numbers, _ or - (must start with a letter or _)."
    return 1
  fi

  _ensure_files

  if ! _exists "${name}"; then
    _err "No snip named '${name}' found."
    return 1
  fi

  if _exists "${newname}"; then
    _err "A snip named '${newname}' already exists. Remove it first."
    return 1
  fi

  # Extract the body, write under new name, remove old
  local body
  body="$(_get_function "${name}" | tail -n +2 | awk 'NR>1{print prev} {prev=$0}')"

  _write_function "${newname}" "${body}"
  _remove_from_file "${name}"

  _nl
  printf "${GREEN}✓${RESET} Snip '${BOLD}%s${RESET}' renamed to '${BOLD}%s${RESET}'.\n" "${name}" "${newname}"
  _reload_hint
}

cmd_edit() {
  local name="$1"

  if [ -z "${name}" ]; then
    _err "Usage: snip edit <name>"
    return 1
  fi

  _ensure_files

  if ! _exists "${name}"; then
    _err "No snip named '${name}' found. Use 'snip add ${name}' to create it."
    return 1
  fi

  # Pre-populate temp file with the existing body
  local tmpfile body
  tmpfile="$(mktemp /tmp/snip_XXXXXX.sh)"
  body="$(_get_function "${name}" | tail -n +2 | awk 'NR>1{print prev} {prev=$0}')"

  cat > "${tmpfile}" <<TEMPLATE
# snip: ${name}
# Edit the command(s) below. Lines starting with # are ignored.
#
# Argument tips:
#   \$1, \$2 …  positional args  →  pip install \$1
#   "\$@"       forward all args →  git pull "\$@"
#
${body}
TEMPLATE

  local editor
  editor="$(_editor)"
  "${editor}" "${tmpfile}"

  # Strip comments and blank lines
  local newbody
  newbody="$(grep -v '^\s*#' "${tmpfile}" | sed '/^[[:space:]]*$/d')"
  rm -f "${tmpfile}"

  if [ -z "${newbody}" ]; then
    _warn "Empty body — snip not updated."
    return 1
  fi

  _write_function "${name}" "${newbody}"

  _nl
  printf "${GREEN}✓${RESET} Snip '${BOLD}%s${RESET}' updated.\n" "${name}"
  _reload_hint
}

cmd_export() {
  _ensure_files

  local file
  file="$(_snip_file)"

  # Check there's anything to export
  local names
  names=$(grep '^[a-zA-Z_][a-zA-Z0-9_-]*()' "${file}" 2>/dev/null | sed 's/().*//')

  if [ -z "${names}" ]; then
    _nl
    _dim "  No snips to export."
    _nl
    return 0
  fi

  _nl
  _bold "  Exporting snips from ${file}"
  _nl
  _dim "  Copy everything below the line and save it somewhere safe."
  _dim "  To import on another machine:  snip import"
  printf "  ${DIM}%s${RESET}\n" "────────────────────────────────────────"
  _nl
  cat "${file}"
  _nl
  printf "  ${DIM}%s${RESET}\n" "────────────────────────────────────────"
  _nl
}

cmd_import() {
  _ensure_files

  local file
  file="$(_snip_file)"

  _nl
  _bold "  Importing snips"
  _nl
  _dim "  Paste your exported snips file content into the editor."
  _dim "  Existing snips with the same name will be overwritten."
  _dim "  Save and quit to confirm."
  _nl

  local tmpfile
  tmpfile="$(mktemp /tmp/snip_XXXXXX.sh)"

  cat > "${tmpfile}" <<TEMPLATE
# Paste your exported snip functions below.
# Lines starting with # are ignored.
# Format: each snip is a shell function like:
#
#   gp() {
#     git pull "\$@"
#   }
#
TEMPLATE

  local editor
  editor="$(_editor)"
  "${editor}" "${tmpfile}"

  # Strip comment lines and blank lines, keep function definitions
  local content
  content="$(grep -v '^\s*#' "${tmpfile}" | sed '/^[[:space:]]*$/d')"
  rm -f "${tmpfile}"

  if [ -z "${content}" ]; then
    _warn "Nothing pasted — import aborted."
    return 1
  fi

  # Parse out function names from the pasted content
  local imported_names
  imported_names=$(printf "%s\n" "${content}" | grep '^[a-zA-Z_][a-zA-Z0-9_-]*()' | sed 's/().*//')

  if [ -z "${imported_names}" ]; then
    _warn "No valid snip functions found in pasted content."
    _dim "  Expected format:  name() { ... }"
    return 1
  fi

  # For each function found, extract and write it
  local count name body
  count=0

  printf "%s\n" "${imported_names}" | while IFS= read -r name; do
    [ -z "${name}" ] && continue
    # Extract this function's body from the pasted content
    body=$(printf "%s\n" "${content}" | awk "/^${name}\(\)/{found=1} found{print} found && /^\}/{exit}" | tail -n +2 | awk 'NR>1{print prev} {prev=$0}')
    _write_function "${name}" "${body}"
    _ok "Imported: ${name}"
    count=$((count + 1))
  done

  _nl
  _reload_hint
}

cmd_list() {
  _ensure_files

  local file names
  file="$(_snip_file)"
  names=$(grep '^[a-zA-Z_][a-zA-Z0-9_-]*()' "${file}" 2>/dev/null | sed 's/().*//')

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
    _get_function "${name}" | tail -n +2 | awk 'NR>1{print prev} {prev=$0}' | sed 's/^/    /'
    _nl
  done
}

cmd_upgrade() {
  _nl
  _info "Upgrading snip..."
  _nl

  local old_version tmp
  old_version="${SNIP_VERSION}"
  tmp="$(mktemp)"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${SNIP_REPO}/snip.sh" -o "${tmp}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${tmp}" "${SNIP_REPO}/snip.sh"
  else
    rm -f "${tmp}"
    _err "Neither curl nor wget found. Cannot upgrade."
    return 1
  fi

  # Sanity check — make sure we got a valid snip script
  if ! grep -q 'SNIP_VERSION=' "${tmp}" 2>/dev/null; then
    rm -f "${tmp}"
    _err "Downloaded file looks invalid. Upgrade aborted — your current install is unchanged."
    return 1
  fi

  # Extract new version from downloaded file
  local new_version
  new_version=$(grep '^SNIP_VERSION=' "${tmp}" | head -1 | sed 's/SNIP_VERSION="//;s/"//')

  chmod +x "${tmp}"
  mv "${tmp}" "${SNIP_DIR}/snip.sh"

  if [ "${old_version}" = "${new_version}" ]; then
    _ok "Already up to date (v${new_version})."
  else
    _ok "Upgraded v${old_version} → v${new_version}"
  fi
  _nl
}

cmd_uninstall() {
  _nl
  _warn "This will:"
  printf "    • Remove %s\n" "${SNIP_DIR}"
  printf "    • Remove the snip lines from your rc file\n"
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

  local shell rc tmp
  shell="$(_detected_shell)"
  rc="${HOME}/.${shell}rc"

  if [ -f "${rc}" ]; then
    tmp="$(mktemp)"
    grep -v '# snip managed' "${rc}" > "${tmp}" && mv "${tmp}" "${rc}"
    _ok "Cleaned ${rc}"
  fi

  rm -rf "${SNIP_DIR}"
  _ok "Removed ${SNIP_DIR}"
  _nl
  _bold "  snip uninstalled. Open a new terminal to clear the session."
  _nl
}

# ── entrypoint ────────────────────────────────

main() {
  cmd="${1:-}"
  shift 2>/dev/null || true

  case "${cmd}" in
    add)               cmd_add "$@" ;;
    edit)              cmd_edit "$@" ;;
    rename|mv)         cmd_rename "$@" ;;
    remove|rm)         cmd_remove "$@" ;;
    list|ls)           cmd_list ;;
    export)            cmd_export ;;
    import)            cmd_import ;;
    upgrade)           cmd_upgrade ;;
    version|-v)        cmd_version ;;
    uninstall)         cmd_uninstall ;;
    help|-h|--help|"") cmd_help ;;
    *)
      _err "Unknown command '${cmd}'. Run 'snip help' for usage."
      exit 1
      ;;
  esac
}

main "$@"
