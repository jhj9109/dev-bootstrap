#!/usr/bin/env bash
doctor() {
  local failures=0 warnings=0
  printf 'Dev Bootstrap — Environment Check\n\n'
  if [[ "$(uname -s)" == Darwin ]]; then log_ok 'macOS detected'; else log_error 'macOS required'; failures=$((failures+1)); fi
  local cmd
  for cmd in git curl xcode-select; do
    if require_command "$cmd"; then log_ok "$cmd available"; else log_error "$cmd missing"; failures=$((failures+1)); fi
  done
  if require_command xcode-select; then
    if xcode-select -p >/dev/null 2>&1; then log_ok 'Xcode Command Line Tools path available'; else log_warn 'Xcode Command Line Tools not configured'; warnings=$((warnings+1)); fi
  fi
  if [[ -d "$WORKSPACE_DIR" ]]; then log_ok 'Workspace exists'; else log_warn "Workspace missing: $WORKSPACE_DIR"; warnings=$((warnings+1)); fi
  if [[ -f "$HOME/.ssh/config" ]]; then log_ok 'SSH config exists'; else log_warn 'SSH config not configured'; warnings=$((warnings+1)); fi
  if require_command node; then log_ok "Node: $(node --version)"; else log_warn 'Node not installed'; warnings=$((warnings+1)); fi
  if require_command python3; then log_ok "Python: $(python3 --version 2>&1)"; else log_warn 'Python not found'; warnings=$((warnings+1)); fi
  printf '\nSummary: %s failure(s), %s warning(s)\n' "$failures" "$warnings"
  (( failures == 0 ))
}
