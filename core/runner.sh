#!/usr/bin/env bash

# Run one registered module. Keep the terminal state, phase and original hook
# code available to the caller. A preflight failure has no hook code.
runner_run() {
  local module_id=$1 index platform hook
  RUNNER_STATUS=FAILED RUNNER_PHASE=registry RUNNER_HOOK_STATUS=''
  index=$(registry_index "$module_id") || {
    log_error "$module_id: unknown module"
    return 1
  }
  RUNNER_PHASE=platform
  platform=$(uname -s) || { log_error "$module_id: platform detection failed"; return 1; }
  if [[ " ${REGISTRY_PLATFORMS[index]} " != *" $platform "* ]]; then
    RUNNER_STATUS=UNSUPPORTED
    log_error "$module_id: UNSUPPORTED ($platform)"
    return 1
  fi

  for RUNNER_PHASE in check apply verify; do
    case "$RUNNER_PHASE" in
      check)  hook=${REGISTRY_CHECK[index]} ;;
      apply)  hook=${REGISTRY_APPLY[index]} ;;
      verify) hook=${REGISTRY_VERIFY[index]} ;;
    esac
    RUNNER_HOOK_STATUS=0
    ( "$hook" ) || RUNNER_HOOK_STATUS=$?
    case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in
      check:10|apply:0) continue ;;
      check:0)  RUNNER_STATUS=SKIPPED ;;
      verify:0) RUNNER_STATUS=SUCCESS ;;
      *:3)      RUNNER_STATUS=BLOCKED ;;
      *:4)      RUNNER_STATUS=NEEDS_ACTION ;;
      *)        RUNNER_STATUS=FAILED ;;
    esac
    break
  done

  case "$RUNNER_STATUS" in
    SKIPPED|SUCCESS) log_ok "$module_id: $RUNNER_STATUS"; return 0 ;;
    *) log_error "$module_id: $RUNNER_STATUS ($RUNNER_PHASE returned $RUNNER_HOOK_STATUS)"; return 1 ;;
  esac
}
