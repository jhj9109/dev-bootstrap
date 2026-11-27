#!/usr/bin/env bash

menu() {
  local choice slot
  while :; do
    printf '\nDev Bootstrap v1.0 (Phase 4)\n1. Check environment\n'
    for slot in "${!REGISTRY_MENU_HANDLERS[@]}"; do
      printf '%s. %s\n' "$slot" "${REGISTRY_MENU_LABELS[slot]}"
    done
    printf '10. Run all\n11. Help\n'
    for slot in "${!REGISTRY_MENU_TARGETS[@]}"; do
      printf '%s. %s\n' "$slot" "${REGISTRY_MENU_LABELS[slot]}"
    done
    printf '0. Exit\nSelect: '
    if ! IFS= read -r choice; then printf '\n'; return 0; fi
    # Reload configuration for each menu action so edits made while the menu
    # is open take effect without restarting the process.
    if [[ "$choice" != 0 ]]; then
      load_config "$ROOT_DIR" "${1-}" || { log_error 'Configuration reload failed; no action taken'; continue; }
    fi
    case "$choice" in
      1) doctor ;;
      10) run_request all '' ;;
      11) usage ;;
      0) return 0 ;;
      *)
        for slot in "${!REGISTRY_MENU_LABELS[@]}"; do
          [[ $choice == "$slot" ]] || continue
          if [[ ${REGISTRY_MENU_HANDLERS[slot]+set} ]]; then
            "${REGISTRY_MENU_HANDLERS[slot]}"
          else
            run_request apply "${REGISTRY_MENU_TARGETS[slot]}"
          fi
          continue 2
        done
        log_warn 'Invalid selection' ;;
    esac
  done
}
