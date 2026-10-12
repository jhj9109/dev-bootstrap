#!/usr/bin/env bash
# Validate in a child process and commit all values only after successful validation.
# A NUL-delimited snapshot avoids evaluating generated shell code in the parent.
load_config() {
  local root="$1" personal="$1/config/profiles.conf" snapshot value name i
  local names=(TARGET_OS WORKSPACE_DIR DEFAULT_AUTH_METHOD DEFAULT_GITHUB_PROFILE NODE_VERSION PYTHON_VERSION INSTALL_ITERM INSTALL_NODE INSTALL_PYTHON PYTHON_INSTALL_METHOD GITHUB_PERSONAL_USER GITHUB_PERSONAL_EMAIL GITHUB_SECONDARY_USER GITHUB_SECONDARY_EMAIL)
  local values=()
  snapshot="$(mktemp "${TMPDIR:-/tmp}/dev-bootstrap-config.XXXXXXXX")" || return 1
  if ! (
    unset GITHUB_PERSONAL_USER GITHUB_PERSONAL_EMAIL GITHUB_SECONDARY_USER GITHUB_SECONDARY_EMAIL
    # Configuration files are trusted Bash input.
    # shellcheck source=/dev/null
    source "$root/config/defaults.conf" || exit 1
    if [[ -f "$personal" ]]; then
      # shellcheck source=/dev/null
      source "$personal" || exit 1
    fi
    case "$TARGET_OS" in macos) ;; *) log_error 'Unsupported TARGET_OS'; exit 2;; esac
    case "$DEFAULT_AUTH_METHOD" in ssh|gh) ;; *) log_error 'Invalid authentication method'; exit 2;; esac
    case "$DEFAULT_GITHUB_PROFILE" in personal|secondary) ;; *) log_error 'Invalid default GitHub profile'; exit 2;; esac
    case "$PYTHON_INSTALL_METHOD" in uv|source) ;; *) log_error 'Invalid Python method'; exit 2;; esac
    [[ "$NODE_VERSION" =~ ^[0-9]+([.][0-9]+){0,2}$ ]] || { log_error 'Invalid Node version'; exit 2; }
    [[ "$PYTHON_VERSION" =~ ^[0-9]+[.][0-9]+([.][0-9]+)?$ ]] || { log_error 'Invalid Python version'; exit 2; }
    [[ -n "$WORKSPACE_DIR" ]] || { log_error 'Empty workspace'; exit 2; }
    for name in "${names[@]}"; do printf '%s\0' "${!name-}"; done
  ) > "$snapshot"; then
    rm -f "$snapshot"
    return 2
  fi
  while IFS= read -r -d '' value; do values+=("$value"); done < "$snapshot"
  rm -f "$snapshot"
  if [[ ${#values[@]} -ne ${#names[@]} ]]; then
    log_error 'Incomplete configuration snapshot'
    return 2
  fi
  for ((i=0; i<${#names[@]}; i++)); do
    printf -v "${names[i]}" '%s' "${values[i]}"
  done
}
