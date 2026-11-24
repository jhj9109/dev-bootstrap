#!/usr/bin/env bash
workspace_status() {
  local path="$WORKSPACE_DIR"
  [[ $path == /* && $path == "$HOME"/* ]] || {
    log_error 'Workspace must be an absolute directory inside HOME'; return 2
  }
  case "$path/" in
    *//*|*/./*|*/../*) log_error 'Unsafe workspace path'; return 2 ;;
  esac
  while [[ $path != "$HOME" ]]; do
    if [[ -L $path || ( -e $path && ( ! -d $path || ! -x $path ) ) ]]; then
      log_error 'Unsafe workspace path'; return 2
    fi
    path=${path%/*}
  done
  workspace_check && return 0
  return 10
}

register_module --id workspace --name Workspace --platforms 'Darwin Linux' \
  --check workspace_status --apply workspace_create --verify workspace_status
