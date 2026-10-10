#!/usr/bin/env bash
set -o pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
for lib in logger common config platform profiles; do
  # shellcheck source=/dev/null
  source "$ROOT_DIR/lib/$lib.sh" || exit 1
done
for module in git auth/ssh auth/gh github shell node python iterm workspace repository; do
  # shellcheck source=/dev/null
  source "$ROOT_DIR/modules/$module.sh" || exit 1
done
usage() {
  cat <<'USAGE'
Dev Bootstrap v1.0 — Phase 4
Usage:
  ./setup.sh                              Interactive menu
  ./setup.sh doctor                       Read-only environment check
  ./setup.sh doctor github [--profile personal|secondary] [--method ssh|gh]
  ./setup.sh configure git [--profile personal|secondary] [--global | --repo PATH]
  ./setup.sh configure github [--profile personal|secondary] [--method ssh|gh] [--no-passphrase]
  ./setup.sh install node [--version X.Y.Z]
  ./setup.sh install python [--version X.Y.Z] [--method uv|source]
  ./setup.sh install iterm
  ./setup.sh configure shell
  ./setup.sh configure workspace
  ./setup.sh repo clone OWNER/REPO [--profile personal|secondary] [--method ssh|gh] [--dest ABS_PATH]
  ./setup.sh repo remote OWNER/REPO --repo PATH [--name origin] [--profile personal|secondary] [--method ssh|gh]
  ./setup.sh all [--profile personal|secondary] [--method ssh|gh] [--no-passphrase]
  ./setup.sh help

Default GitHub method: ssh. Default Git identity scope: --global.
--no-passphrase explicitly permits creating an unencrypted SSH private key.
GitHub key registration is manual. The gh method requires a preinstalled gh CLI.
Node uses nvm, Python uses uv by default; source builds require a full X.Y.Z version.
USAGE
}
parse_options() {
  PROFILE="$DEFAULT_GITHUB_PROFILE" METHOD="$DEFAULT_AUTH_METHOD" SCOPE=global REPO='' NO_PASSPHRASE=false
  while (( $# )); do
    case "$1" in
      --profile|--method|--repo)
        local opt="$1"; shift
        [[ $# -gt 0 && -n "$1" && "$1" != --* ]] || { log_error "Missing value for $opt"; return 2; }
        case "$opt" in --profile) PROFILE="$1";; --method) METHOD="$1";; --repo) REPO="$1"; SCOPE=local;; esac ;;
      --global) SCOPE=global ;;
      --no-passphrase) NO_PASSPHRASE=true ;;
      *) log_error "Unknown option: $1"; return 2;;
    esac
    shift
  done
  case "$PROFILE" in personal|secondary) ;; *) log_error 'Invalid profile'; return 2;; esac
  case "$METHOD" in ssh|gh) ;; *) log_error 'Invalid auth method'; return 2;; esac
}
parse_install_options() {
  INSTALL_VERSION='' INSTALL_METHOD="$PYTHON_INSTALL_METHOD"
  while (( $# )); do
    case "$1" in
      --version|--method)
        local opt="$1"; shift
        [[ $# -gt 0 && -n "$1" && "$1" != --* ]] || { log_error "Missing value for $opt"; return 2; }
        if [[ "$opt" == --version ]]; then INSTALL_VERSION="$1"; else INSTALL_METHOD="$1"; fi ;;
      *) log_error "Unknown install option: $1"; return 2 ;;
    esac
    shift
  done
  case "$INSTALL_METHOD" in uv|source) ;; *) log_error 'Invalid Python installation method'; return 2;; esac
  if [[ -n "$INSTALL_VERSION" && ! "$INSTALL_VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    log_error 'Invalid version'; return 2
  fi
}
run_install() {
  local target="$1"; shift
  parse_install_options "$@" || return $?
  case "$target" in
    node)
      [[ "$INSTALL_METHOD" == "$PYTHON_INSTALL_METHOD" ]] || { log_error '--method is Python-only'; return 2; }
      local version="${INSTALL_VERSION:-$NODE_VERSION}"
      if node_check "$version"; then
        # Ensure default version and future shell sessions work even when installed already.
        nvm alias default "$version" >/dev/null || return 1
        shell_configure || return 1
        log_ok "Node.js $version already installed"
      else node_install "$version"; fi ;;
    python)
      local version="${INSTALL_VERSION:-$PYTHON_VERSION}"
      if python_check "$version" "$INSTALL_METHOD"; then
        [[ "$INSTALL_METHOD" == uv ]] && shell_configure || [[ "$INSTALL_METHOD" == source ]] || return 1
        log_ok "Python $version already installed ($INSTALL_METHOD)"
      else python_install "$version" "$INSTALL_METHOD"; fi ;;
    iterm)
      [[ -z "$INSTALL_VERSION" && "$INSTALL_METHOD" == "$PYTHON_INSTALL_METHOD" ]] || { log_error 'iTerm2 accepts no options'; return 2; }
      if iterm_check; then log_ok 'iTerm2 already installed'; else iterm_install; fi ;;
    *) log_error "Unknown install target: $target"; return 2 ;;
  esac
}
run_all() {
  local profile="$1" method="$2" no_passphrase="$3" failures=0
  log_info 'Starting full setup; failures will be summarized'
  workspace_configure || { log_warn 'Workspace step failed'; failures=$((failures+1)); }
  configure_git "$profile" global '' || { log_warn 'Git step failed'; failures=$((failures+1)); }
  configure_github "$profile" "$method" "$no_passphrase" || { log_warn 'GitHub authentication step requires attention'; failures=$((failures+1)); }
  shell_configure || { log_warn 'Shell step failed'; failures=$((failures+1)); }
  if [[ "$INSTALL_NODE" == true ]]; then run_install node || { log_warn 'Node step failed'; failures=$((failures+1)); }; fi
  if [[ "$INSTALL_PYTHON" == true ]]; then run_install python || { log_warn 'Python step failed'; failures=$((failures+1)); }; fi
  if [[ "$INSTALL_ITERM" == true ]]; then run_install iterm || { log_warn 'iTerm step failed'; failures=$((failures+1)); }; fi
  if [[ -f "$ROOT_DIR/config/repositories.conf" ]]; then
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -z "$line" ]] && continue
      repo_clone "$line" "$profile" "$method" || { log_warn "Repository step failed: $line"; failures=$((failures+1)); }
    done < "$ROOT_DIR/config/repositories.conf"
  fi
  log_info "Setup finished with $failures failed/attention step(s)"
  (( failures == 0 ))
}
menu() {
  local choice
  while :; do
    printf '\nDev Bootstrap v1.0 (Phase 4)\n1. Check environment\n2. Configure Git identity\n3. Configure GitHub (SSH default)\n4. Verify GitHub authentication\n5. Install Node.js\n6. Install Python\n7. Install iTerm2\n8. Configure zsh\n9. Configure Workspace\n10. Run all\n11. Help\n0. Exit\nSelect: '
    if ! IFS= read -r choice; then printf '\n'; return 0; fi
    case "$choice" in
      1) doctor ;;
      2) configure_git "$DEFAULT_GITHUB_PROFILE" global '' ;;
      3) configure_github "$DEFAULT_GITHUB_PROFILE" "$DEFAULT_AUTH_METHOD" false ;;
      4) github_doctor "$DEFAULT_GITHUB_PROFILE" "$DEFAULT_AUTH_METHOD" ;;
      5) run_install node ;;
      6) run_install python ;;
      7) run_install iterm ;;
      8) shell_configure ;;
      9) workspace_configure ;;
      10) run_all "$DEFAULT_GITHUB_PROFILE" "$DEFAULT_AUTH_METHOD" false ;;
      11) usage ;;
      0) return 0 ;;
      *) log_warn 'Invalid selection' ;;
    esac
  done
}
main() {
  load_config "$ROOT_DIR" || return $?
  local action="${1:-}" target="${2:-}"
  case "$action" in
    '') [[ $# -eq 0 ]] || return 2; menu ;;
    help|-h|--help) usage ;;
    doctor)
      if [[ $# -eq 1 ]]; then doctor
      elif [[ "$target" == github ]]; then shift 2; parse_options "$@" || return $?; github_doctor "$PROFILE" "$METHOD"
      else usage; return 2; fi ;;
    repo)
      [[ $# -ge 3 ]] || { usage; return 2; }
      local operation="$target" spec="$3" dest='' name='origin'
      shift 3
      PROFILE="$DEFAULT_GITHUB_PROFILE" METHOD="$DEFAULT_AUTH_METHOD" REPO=''
      while (( $# )); do
        case "$1" in
          --profile|--method|--repo|--dest|--name)
            local opt="$1"; shift
            [[ $# -gt 0 && -n "$1" && "$1" != --* ]] || { log_error "Missing $opt value"; return 2; }
            case "$opt" in
              --profile) PROFILE="$1";; --method) METHOD="$1";; --repo) REPO="$1";; --dest) dest="$1";; --name) name="$1";;
            esac ;;
          *) log_error "Unknown repo option: $1"; return 2;;
        esac
        shift
      done
      case "$PROFILE" in personal|secondary) ;; *) return 2;; esac
      case "$METHOD" in ssh|gh) ;; *) return 2;; esac
      case "$operation" in
        clone) [[ -z "$REPO" && "$name" == origin ]] || return 2; repo_clone "$spec" "$PROFILE" "$METHOD" "$dest" ;;
        remote) [[ -n "$REPO" && -z "$dest" ]] || { log_error 'remote requires --repo PATH'; return 2; }; repo_remote "$REPO" "$spec" "$PROFILE" "$METHOD" "$name" ;;
        *) log_error 'Unknown repo operation'; return 2;;
      esac ;;
    all)
      shift; parse_options "$@" || return $?
      [[ "$SCOPE" == global && -z "$REPO" ]] || return 2
      run_all "$PROFILE" "$METHOD" "$NO_PASSPHRASE" ;;
    install)
      [[ $# -ge 2 ]] || { usage; return 2; }
      shift 2; run_install "$target" "$@" ;;
    configure)
      [[ $# -ge 2 ]] || { usage; return 2; }
      if [[ "$target" == workspace ]]; then
        [[ $# -eq 2 ]] || return 2
        workspace_configure; return $?
      fi
      if [[ "$target" == shell ]]; then
        [[ $# -eq 2 ]] || { log_error 'Shell accepts no options'; return 2; }
        shell_configure; return $?
      fi
      shift 2; parse_options "$@" || return $?
      case "$target" in
        git) [[ "$NO_PASSPHRASE" == false && "$METHOD" == "$DEFAULT_AUTH_METHOD" ]] || { log_error 'Unsupported Git option'; return 2; }; configure_git "$PROFILE" "$SCOPE" "$REPO" ;;
        github) [[ "$SCOPE" == global && -z "$REPO" ]] || { log_error '--repo is not supported for GitHub auth'; return 2; }; configure_github "$PROFILE" "$METHOD" "$NO_PASSPHRASE" ;;
        *) usage; return 2;;
      esac ;;
    *) log_error "Unsupported command: $action"; usage; return 2 ;;
  esac
}
main "$@"
