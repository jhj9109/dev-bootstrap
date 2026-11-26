#!/usr/bin/env bash

workspace_defaults() { WORKSPACE_DIR="$HOME/Documents"; }

workspace_validate() {
  [[ -n $WORKSPACE_DIR ]] || { log_error 'Empty workspace'; return 2; }
}

workspace_status() {
  workspace_validate_path || return $?
  workspace_check && return 0
  return 10
}

register_module --id workspace --name Workspace --platforms 'Darwin Linux' \
  --keys 'WORKSPACE_DIR' --defaults workspace_defaults --validate workspace_validate \
  --check workspace_status --apply workspace_configure --verify workspace_status
