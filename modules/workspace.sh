#!/usr/bin/env bash
workspace_check() { [[ -d "$WORKSPACE_DIR" && ! -L "$WORKSPACE_DIR" ]]; }
workspace_configure() {
  [[ "$WORKSPACE_DIR" == "$HOME"/* && "$WORKSPACE_DIR" != "$HOME" ]] || { log_error 'Workspace must be an absolute directory inside HOME'; return 2; }
  [[ ! -L "$WORKSPACE_DIR" && ( ! -e "$WORKSPACE_DIR" || -d "$WORKSPACE_DIR" ) ]] || { log_error 'Unsafe workspace path'; return 2; }
  mkdir -p -- "$WORKSPACE_DIR" || return 1
  workspace_check || return 5
  log_ok "Workspace ready: $WORKSPACE_DIR"
}
