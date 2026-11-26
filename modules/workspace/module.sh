#!/usr/bin/env bash
workspace_status() {
  workspace_validate_path || return $?
  workspace_check && return 0
  return 10
}

register_module --id workspace --name Workspace --platforms 'Darwin Linux' \
  --check workspace_status --apply workspace_configure --verify workspace_status
