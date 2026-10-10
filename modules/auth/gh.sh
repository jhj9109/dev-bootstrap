#!/usr/bin/env bash
gh_setup() {
  local profile="$1"
  profile_load "$profile" || return $?
  require_command gh || { log_error 'GitHub CLI (gh) is not installed. Install it first; Phase 3 will support installation.'; return 3; }
  if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    [[ -t 0 ]] || { log_error 'Interactive terminal required for gh auth login'; return 4; }
    gh auth login --hostname github.com --git-protocol https || return 4
  fi
  local account
  account="$(gh api user --jq .login 2>/dev/null)" || return 4
  if [[ "$account" != "$PROFILE_USER" ]]; then
    log_error "Active gh account '$account' does not match profile '$PROFILE_USER'. Switch using gh auth switch -h github.com -u '$PROFILE_USER'"
    return 4
  fi
  gh auth setup-git || return 1
  log_ok "GitHub CLI HTTPS authentication ready for $account"
}
gh_doctor() {
  local profile="$1"
  profile_load "$profile" || return $?
  require_command gh || { log_warn 'gh not installed'; return 3; }
  local account
  account="$(gh api user --jq .login 2>/dev/null)" || { log_warn 'gh not authenticated'; return 4; }
  [[ "$account" == "$PROFILE_USER" ]] || { log_warn "Active gh account: $account (expected $PROFILE_USER)"; return 4; }
  log_ok "gh authenticated as $account"
}
