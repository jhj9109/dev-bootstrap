#!/usr/bin/env bash
configure_github() {
  local github_profile=$1 github_method=$2 github_unencrypted=$3
  local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
  case "$github_method:$github_unencrypted" in ssh:true|ssh:false|gh:false) ;; *) return 2 ;; esac
  if runner_run github; then
    if [[ $github_method == ssh ]]; then
      printf 'Register the public key %s in GitHub Settings > SSH and GPG keys.\n' "$HOME/.ssh/dev-bootstrap-$github_profile.pub"
      printf 'Verify authentication with ./setup.sh doctor github --method ssh --profile %s\n' "$github_profile"
    fi
    return 0
  fi
  case "$RUNNER_STATUS" in BLOCKED|UNSUPPORTED) return 3 ;; NEEDS_ACTION) return 4 ;; esac
  case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in verify:*|*:5) return 5 ;; *:2) return 2 ;; *) return 1 ;; esac
}
github_doctor() {
  profile_load "$1" || return $?
  case "$2" in ssh) ssh_doctor ;; gh) gh_doctor ;; *) return 2 ;; esac
}
