#!/usr/bin/env bash
shell_configure() {
  local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
  runner_run shell || return 1
  if [[ $RUNNER_STATUS == SUCCESS ]]; then
    log_ok 'zsh initialization configured (open a new terminal to apply)'
  fi
  return 0
}

# Legacy runtime installs may repair Shell. Planned operations own only their
# module, including when Shell changed after the dependency probe.
shell_runtime_status() {
  local rc=0
  shell_check || rc=$?
  if [[ ${RUNNER_PLANNED:-0} == 1 && $rc == 10 ]]; then
    log_error 'Shell prerequisite needs changes'; return 3
  fi
  return "$rc"
}
