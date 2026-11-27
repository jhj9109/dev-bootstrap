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
  --prerequisites 'Installing the app on Darwin needs curl and ditto.' \
  --check iterm_status --apply iterm_install --verify iterm_verify

iterm_command_install() {
  parse_install_options "$@" || return $?
  [[ -z "$INSTALL_VERSION" && "$INSTALL_METHOD" == "$PYTHON_INSTALL_METHOD" ]] || { log_error 'iTerm2 accepts no options'; return 2; }
  local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
  local start=$SECONDS
  if runner_run iterm; then
    if [[ $RUNNER_STATUS == SKIPPED ]]; then log_ok 'iTerm2 already installed'
    else log_ok "iTerm2 installed in ~/Applications ($((SECONDS - start))s total)"; fi
    return 0
  fi
  case "$RUNNER_STATUS" in BLOCKED|UNSUPPORTED) return 3 ;; esac
  case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in verify:*|apply:5) return 5 ;; *) return 1 ;; esac
}
register_command 'install iterm' iterm_command_install '' 7 'Install iTerm2'
