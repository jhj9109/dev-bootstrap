#!/usr/bin/env bash

# Return 10 only when gh explicitly reports no login on this host.
gh_account_status() {
  local msg rc=0 account
  require_command gh || { log_error 'GitHub CLI is required'; return 3; }
  msg=$(LC_ALL=C GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 gh auth status --hostname github.com 2>&1) || rc=$?
  if [[ $rc != 0 ]]; then
    case "$rc:${msg%%$'\n'*}" in
      [14]:'You are not logged into any GitHub hosts'*|[14]:'You are not logged into any accounts on github.com'*|[14]:'You are not logged into the GitHub host "github.com"'*) return 10 ;;
      4:*) log_warn 'GitHub CLI authentication requires attention'; return 4 ;;
      *) log_error 'Cannot determine gh authentication status'; return 1 ;;
    esac
  fi
  account=$(GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 gh api --hostname github.com user --jq .login 2>/dev/null) || {
    log_error 'Cannot query the active GitHub account'; return 1
  }
  [[ $account =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] || { log_error 'Invalid GitHub account response'; return 1; }
  if [[ $(printf %s "$account" | tr A-Z a-z) != "$(printf %s "$PROFILE_USER" | tr A-Z a-z)" ]]; then
    log_warn "Select GitHub account $PROFILE_USER before continuing"; return 4
  fi
}

# Preserve trailing empty helpers (which reset the chain). Use a terminator
# because shell command substitution otherwise drops trailing newlines.
gh_host_helper() {
  local host=$1 rc=0 values
  shift
  values=$(git config "$@" --includes --get-all "credential.https://$host.helper" 2>&1 && printf .) || rc=$?
  if [[ $rc == 1 && -z $values ]]; then return 10; fi
  [[ $rc == 0 ]] || { log_error 'Cannot read Git credential configuration'; return 1; }
  local command generic
  for command in gh "$exe" "'$exe'" "\"$exe\""; do
    [[ $values == $'\n'!"$command auth git-credential"$'\n.' ]] && return 0
    if [[ $values == !"$command auth git-credential"$'\n.' ]]; then
      rc=0
      generic=$(git config "$@" --includes --get-all credential.helper 2>&1) || rc=$?
      if [[ -z $generic && ( $rc == 0 || $rc == 1 ) ]]; then return 0; fi
      [[ $rc == 0 ]] || return 1
    fi
  done
  log_warn "Review existing credential helper for $host"; return 4
}

gh_helpers_status() {
  local host rc exe missing=0
  require_command git || return 3
  exe=$(command -v gh) || return 3
  for host in github.com gist.github.com; do
    # setup-git can also write gist.github.com. Check it before that operation.
    if [[ $host == gist.github.com && $missing == 0 ]]; then break; fi
    rc=0
    gh_host_helper "$host" --global || rc=$?
    case "$rc" in
      0) ;;
      10) if [[ $host == github.com ]]; then missing=10; fi ;;
      *) return "$rc" ;;
    esac
    # A repository or included config may override the global host setup.
    rc=0
    gh_host_helper "$host" || rc=$?
    case "$rc" in 0|10) ;; *) return "$rc" ;; esac
  done
  return "$missing"
}

gh_inspect() {
  auth=0 helper=0
  gh_account_status || auth=$?
  case "$auth" in 0|10) ;; *) return "$auth" ;; esac
  gh_helpers_status || helper=$?
  case "$helper" in 0|10) ;; *) return "$helper" ;; esac
  if [[ $auth == 10 ]]; then
    [[ -t 0 ]] || { log_warn 'Interactive terminal required for gh auth login'; return 4; }
    return 10
  fi
  return "$helper"
}

gh_local_status() {
  local auth helper
  gh_inspect
}

gh_setup() {
  local auth helper rc=0
  gh_inspect || rc=$?
  [[ $rc == 10 ]] || return "$rc"
  if [[ $auth == 10 ]]; then
    [[ -t 0 ]] || return 4
    gh auth login --hostname github.com --git-protocol https || return 4
    gh_doctor || return $?
    # Login itself can configure Git when the user accepts gh's prompt.
    helper=0
    gh_helpers_status || helper=$?
  fi
  [[ $helper == 10 ]] || return "$helper"
  gh auth setup-git --hostname github.com >/dev/null 2>&1 || return 1
}

gh_doctor() {
  local rc=0
  gh_account_status || rc=$?
  case "$rc" in
    0) log_ok "GitHub authenticated as $PROFILE_USER" ;;
    10) log_warn 'No active github.com login'; return 4 ;;
    *) return "$rc" ;;
  esac
}
