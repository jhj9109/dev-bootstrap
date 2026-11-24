#!/usr/bin/env bash

iterm_verify() {
  iterm_safe_destination || return 1
  iterm_check && return 0
  return 10
}

iterm_status() {
  local rc=0 cmd
  iterm_verify || rc=$?
  [[ $rc == 10 ]] || return "$rc"
  for cmd in curl ditto; do
    require_command "$cmd" || { log_error "Missing $cmd"; return 3; }
  done
  return 10
}

register_module --id iterm --name iTerm2 --platforms Darwin \
  --check iterm_status --apply iterm_install --verify iterm_verify
