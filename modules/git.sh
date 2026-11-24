#!/usr/bin/env bash
configure_git() {
  local identity_profile=$1 identity_scope=$2 identity_repo=$3
  local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
  if runner_run git; then
    log_ok "Git $identity_scope identity configured for $identity_profile"
    return 0
  fi
  case "$RUNNER_STATUS" in BLOCKED|UNSUPPORTED) return 3 ;; esac
  case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in
    verify:*) return 5 ;;
    check:2|apply:2) return 2 ;;
    *) return 1 ;;
  esac
}
