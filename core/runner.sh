#!/usr/bin/env bash

# Run one registered module. Keep the terminal state, phase and original hook
# code available to the caller. A preflight failure has no hook code.
runner_run() {
  local module_id=$1 mode=${2:-apply} index platform hook
  RUNNER_REASON='unknown module'
  RUNNER_STATUS=FAILED RUNNER_PHASE=registry RUNNER_HOOK_STATUS=''
  index=$(registry_index "$module_id") || {
    log_error "$module_id: unknown module"
    return 1
  }
  RUNNER_PHASE=platform
  RUNNER_REASON='platform detection failed'
  platform=$(uname -s) || { log_error "$module_id: platform detection failed"; return 1; }
  if [[ " ${REGISTRY_PLATFORMS[index]} " != *" $platform "* ]]; then
    RUNNER_STATUS=UNSUPPORTED RUNNER_REASON="unsupported platform $platform"
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
    RUNNER_REASON='goal satisfied'
    case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in
      check:10)
        if [[ $mode == apply ]]; then continue; fi
        RUNNER_STATUS=CHANGE_NEEDED RUNNER_REASON='goal needs changes' ;;
      apply:0) continue ;;
      check:0)  RUNNER_STATUS=SKIPPED ;;
      verify:0) RUNNER_STATUS=SUCCESS ;;
      *:3)      RUNNER_STATUS=BLOCKED RUNNER_REASON="prerequisite unavailable (hook exit 3)" ;;
      *:4)      RUNNER_STATUS=NEEDS_ACTION RUNNER_REASON="user action required (hook exit 4)" ;;
      *)        RUNNER_STATUS=FAILED RUNNER_REASON="$RUNNER_PHASE failed (hook exit $RUNNER_HOOK_STATUS)" ;;
    esac
    break
  done

  case "$RUNNER_STATUS" in
    SKIPPED|SUCCESS) log_ok "$module_id: $RUNNER_STATUS"; return 0 ;;
    CHANGE_NEEDED) log_info "$module_id: $RUNNER_STATUS"; return 1 ;;
    *) log_error "$module_id: $RUNNER_STATUS ($RUNNER_PHASE returned $RUNNER_HOOK_STATUS)"; return 1 ;;
  esac
}

# The CLI owns request context. Only the validated order, edges and prior
# outcomes decide which registered hooks may run.
runner_execute_plan() {
  local action=$1 requested=$2 index id dependency parent mode failed=0 retry_action=apply
  local RUNNER_STATUS RUNNER_PHASE RUNNER_REASON RUNNER_HOOK_STATUS
  local -a statuses=() phases=() reasons=()
  local -a required
  if [[ $action == check ]]; then retry_action=check; fi
  for index in ${plan_order[@]+"${plan_order[@]}"}; do
    id=${REGISTRY_IDS[index]}
    RUNNER_STATUS=''
    IFS=' ' read -r -a required <<< "${plan_deps[index]}"
    for dependency in ${required[@]+"${required[@]}"}; do
      parent=$(registry_index "$dependency") || return 2
      case "${statuses[parent]}" in
        SUCCESS|SKIPPED) ;;
        *)
          RUNNER_STATUS=BLOCKED RUNNER_PHASE=dependency
          RUNNER_REASON="requires $dependency (${statuses[parent]})"
          break ;;
      esac
    done
    if [[ -z $RUNNER_STATUS ]]; then
      mode=apply
      if [[ $action == check || ( -n $requested && $id != "$requested" ) ]]; then mode=check; fi
      runner_run "$id" "$mode" || :
    fi
    statuses[index]=$RUNNER_STATUS phases[index]=$RUNNER_PHASE reasons[index]=$RUNNER_REASON
    case "$RUNNER_STATUS" in SUCCESS|SKIPPED) ;; *) failed=$((failed+1)) ;; esac
  done

  printf 'Summary: %d module(s), %d incomplete\n' "${#plan_order[@]}" "$failed"
  for index in ${plan_order[@]+"${plan_order[@]}"}; do
    id=${REGISTRY_IDS[index]}
    printf '%s: %s | %s | %s\n' "$id" "${statuses[index]}" "${phases[index]}" "${reasons[index]}"
    printf '  Retry: ./setup.sh %s %q' "$retry_action" "$id"
    if [[ $id == "$requested" ]]; then
      printf ' %q' "${retry_options[@]}"
    else
      printf ' %q' "${common_options[@]}"
    fi
    printf '\n'
  done
  (( failed == 0 ))
}
