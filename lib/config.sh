#!/usr/bin/env bash
load_config() {
  local root="$1" personal="$1/config/profiles.conf"
  # Prevent stale profile values if profiles.conf was removed or fields were deleted.
  unset GITHUB_PERSONAL_USER GITHUB_PERSONAL_EMAIL GITHUB_SECONDARY_USER GITHUB_SECONDARY_EMAIL
  # Configuration files are Bash and must be trusted before sourcing.
  # shellcheck source=/dev/null
  source "$root/config/defaults.conf" || return 1
  if [[ -f "$personal" ]]; then
    # shellcheck source=/dev/null
    source "$personal" || return 1
  fi
  case "$TARGET_OS" in macos) ;; *) log_error 'Unsupported TARGET_OS'; return 2;; esac
  case "$DEFAULT_AUTH_METHOD" in ssh|gh) ;; *) log_error 'Invalid authentication method'; return 2;; esac
  case "$PYTHON_INSTALL_METHOD" in uv|source) ;; *) log_error 'Invalid Python method'; return 2;; esac
  [[ "$NODE_VERSION" =~ ^[0-9]+([.][0-9]+){0,2}$ ]] || { log_error 'Invalid Node version'; return 2; }
  [[ "$PYTHON_VERSION" =~ ^[0-9]+[.][0-9]+([.][0-9]+)?$ ]] || { log_error 'Invalid Python version'; return 2; }
  [[ -n "$WORKSPACE_DIR" ]] || { log_error 'Empty workspace'; return 2; }
}
