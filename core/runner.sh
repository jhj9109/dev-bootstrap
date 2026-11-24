#!/usr/bin/env bash

# Results describe the terminal phase. An empty hook status means no hook ran.
# The function succeeds only when the module's goal was met.
runner_run() {
  local runner_id="$1" runner_index runner_platform runner_hook
  RUNNER_STATUS=FAILED RUNNER_PHASE=registry RUNNER_HOOK_STATUS=''
  if ! runner_index=$(registry_index "$runner_id"); then
    log_error "$runner_id: FAILED (unknown module)"
    return 1
  fi

  RUNNER_PHASE=platform
  if ! runner_platform=$(uname -s); then
    log_error "$runner_id: FAILED (platform detection)"
    return 1
  fi
  if [[ " ${REGISTRY_PLATFORMS[runner_index]} " != *" $runner_platform "* ]]; then
    RUNNER_STATUS=UNSUPPORTED
    log_error "$runner_id: UNSUPPORTED ($runner_platform)"
    return 1
  fi

  for RUNNER_PHASE in check apply verify; do
    case "$RUNNER_PHASE" in
      check) runner_hook=${REGISTRY_CHECK[runner_index]} ;;
      apply) runner_hook=${REGISTRY_APPLY[runner_index]} ;;
      verify) runner_hook=${REGISTRY_VERIFY[runner_index]} ;;
    esac
    # Each hook starts from the same settings and working directory.
    RUNNER_HOOK_STATUS=0
    ( "$runner_hook" ) || RUNNER_HOOK_STATUS=$?
    case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in
      check:10|apply:0) continue ;;
      check:0) RUNNER_STATUS=SKIPPED ;;
      verify:0) RUNNER_STATUS=SUCCESS ;;
      *:3) RUNNER_STATUS=BLOCKED ;;
      *:4) RUNNER_STATUS=NEEDS_ACTION ;;
    esac
    break
  done

  case "$RUNNER_STATUS" in
    SUCCESS|SKIPPED) log_ok "$runner_id: $RUNNER_STATUS"; return 0 ;;
    *) log_error "$runner_id: $RUNNER_STATUS ($RUNNER_PHASE exited $RUNNER_HOOK_STATUS)"; return 1 ;;
  esac
}
