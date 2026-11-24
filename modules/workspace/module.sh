#!/usr/bin/env bash
workspace_status() {
  local path="$WORKSPACE_DIR"
  [[ $path == "$HOME"/* ]] || return 1
  case "$path/" in *//*|*/./*|*/../*) return 1 ;; esac
  while [[ $path != "$HOME" ]]; do
    [[ ! -L $path ]] || return 1
    if [[ -e $path ]]; then
      [[ -d $path && -x $path ]] || return 1
    fi
    path=${path%/*}
  done
  workspace_check && return 0
  return 10
}

register_module --id workspace --name Workspace --platforms 'Darwin Linux' \
  --check workspace_status --apply workspace_configure --verify workspace_status
