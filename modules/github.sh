#!/usr/bin/env bash
configure_github() {
  local profile="$1" method="$2" no_passphrase="$3"
  case "$method" in
    ssh) ssh_setup "$profile" "$no_passphrase" ;;
    gh) [[ "$no_passphrase" == false ]] || { log_error '--no-passphrase is SSH-only'; return 2; }; gh_setup "$profile" ;;
    *) log_error "Unknown auth method: $method"; return 2;;
  esac
}
github_doctor() {
  local profile="$1" method="$2"
  case "$method" in ssh) ssh_doctor "$profile" ;; gh) gh_doctor "$profile" ;; *) return 2;; esac
}
