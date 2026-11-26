#!/usr/bin/env bash

menu() {
  local choice
  while :; do
    printf '\nDev Bootstrap v1.0 (Phase 4)\n1. Check environment\n2. Configure Git identity\n3. Configure GitHub (SSH default)\n4. Verify GitHub authentication\n5. Install Node.js\n6. Install Python\n7. Install iTerm2\n8. Configure zsh\n9. Configure Workspace\n10. Run all\n11. Help\n0. Exit\nSelect: '
    if ! IFS= read -r choice; then printf '\n'; return 0; fi
    # Reload configuration for each menu action so edits made while the menu
    # is open take effect without restarting the process.
    if [[ "$choice" != 0 ]]; then
      load_config "$ROOT_DIR" "${1-}" || { log_error 'Configuration reload failed; no action taken'; continue; }
    fi
    case "$choice" in
      1) doctor ;;
      2) configure_git "$DEFAULT_GITHUB_PROFILE" global '' ;;
      3) configure_github "$DEFAULT_GITHUB_PROFILE" "$DEFAULT_AUTH_METHOD" false ;;
      4) github_doctor "$DEFAULT_GITHUB_PROFILE" "$DEFAULT_AUTH_METHOD" ;;
      5) run_install node ;;
      6) run_install python ;;
      7) run_install iterm ;;
      8) shell_configure ;;
      9) run_workspace ;;
      10) run_all "$DEFAULT_GITHUB_PROFILE" "$DEFAULT_AUTH_METHOD" false ;;
      11) usage ;;
      0) return 0 ;;
      *) log_warn 'Invalid selection' ;;
    esac
  done
}
