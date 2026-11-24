#!/usr/bin/env bash
shell_configure() {
  local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
  runner_run shell || return 1
  if [[ $RUNNER_STATUS == SUCCESS ]]; then
    log_ok 'zsh initialization configured (open a new terminal to apply)'
  fi
  return 0
}
