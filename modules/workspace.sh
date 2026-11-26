#!/usr/bin/env bash
workspace_check() { [[ -d "$WORKSPACE_DIR" && ! -L "$WORKSPACE_DIR" ]]; }
workspace_validate_path() {
  local path="$WORKSPACE_DIR"
  [[ $path == /* && $path == "$HOME"/* ]] || return 2
  case "$path/" in *//*|*/./*|*/../*) return 2 ;; esac
  while [[ $path != "$HOME" ]]; do
    [[ ! -L $path ]] || return 2
    if [[ -e $path ]]; then
      [[ -d $path ]] || return 2
      [[ -x $path ]] || return 1
    fi
    path=${path%/*}
  done
  [[ ! -L $HOME ]] || return 2
}
workspace_configure() {
  local rc
  workspace_validate_path || { rc=$?; log_error 'Unsafe workspace path'; return "$rc"; }
  mkdir -p -- "$WORKSPACE_DIR" || return 1
  workspace_check || return 5
  log_ok "Workspace ready: $WORKSPACE_DIR"
}
