#!/usr/bin/env bash

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
  ./setup.sh plan [--profile personal|secondary] [--method ssh|gh] [--no-passphrase]
  ./setup.sh check [MODULE] [options]
  ./setup.sh apply [MODULE] [options]
  ./setup.sh all [--dry-run] [--profile personal|secondary] [--method ssh|gh] [--no-passphrase]
  ./setup.sh help

Select an environment for any command or the menu with --environment classroom|minimal.
Default GitHub method: ssh. Default Git identity scope: --global.
--no-passphrase explicitly permits creating an unencrypted SSH private key.
GitHub key registration is manual. The gh method requires a preinstalled gh CLI.
Node uses nvm, Python uses uv by default; source builds require a full X.Y.Z version.
USAGE
}
parse_options() {
  local command_name=$1 option_target=$2 explicit_global=false aggregate=false
  shift 2
  case $command_name in plan|all|apply|check) aggregate=true ;; esac
  PROFILE="$DEFAULT_GITHUB_PROFILE" METHOD="$DEFAULT_AUTH_METHOD" SCOPE=global REPO='' NO_PASSPHRASE=false
  while (( $# )); do
    case "$1" in
      --profile|--method|--repo|--version)
        local opt="$1"; shift
        [[ $# -gt 0 && -n "$1" && "$1" != --* ]] || { log_error "Missing value for $opt"; return 2; }
        case "$opt" in
          --profile) PROFILE="$1" ;;
          --method)
            if [[ $aggregate == true && $option_target == python && ( $1 == uv || $1 == source ) ]]; then
              PYTHON_INSTALL_METHOD=$1
            else
              METHOD=$1
            fi ;;
          --version)
            [[ $aggregate == true && $1 =~ ^[0-9]+([.][0-9]+){0,2}$ ]] || return 2
            case $option_target in node) NODE_VERSION=$1 ;; python) PYTHON_VERSION=$1 ;; *) return 2 ;; esac ;;
          --repo)
            [[ $aggregate == false || $option_target == git ]] || return 2
            [[ $explicit_global == false ]] || { log_error 'Conflicting Git scopes'; return 2; }
            REPO="$1"; SCOPE=local ;;
        esac ;;
      --dry-run)
        [[ $command_name == all && $dry_run == false ]] || { log_error 'Unexpected --dry-run'; return 2; }
        dry_run=true ;;
      --global)
        [[ $aggregate == false || $option_target == git ]] || return 2
        [[ -z $REPO ]] || { log_error 'Conflicting Git scopes'; return 2; }
        explicit_global=true; SCOPE=global ;;
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
      local node_request="${INSTALL_VERSION:-$NODE_VERSION}"
      local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
      runner_run node && return 0
      case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in
        verify:*|apply:5) return 5 ;;
        *) return 1 ;;
      esac ;;
    python)
      local python_request="${INSTALL_VERSION:-$PYTHON_VERSION}" python_method="$INSTALL_METHOD"
      local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
      python_validate_request "$python_method" "$python_request" || return $?
      runner_run python && return 0
      case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in
        verify:*|apply:5) return 5 ;;
        check:2|apply:2) return 2 ;;
        check:3|apply:3) return 3 ;;
        *) return 1 ;;
      esac ;;
    iterm)
      [[ -z "$INSTALL_VERSION" && "$INSTALL_METHOD" == "$PYTHON_INSTALL_METHOD" ]] || { log_error 'iTerm2 accepts no options'; return 2; }
      local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
      local start=$SECONDS
      if runner_run iterm; then
        if [[ $RUNNER_STATUS == SKIPPED ]]; then log_ok 'iTerm2 already installed'
        else log_ok "iTerm2 installed in ~/Applications ($((SECONDS - start))s total)"; fi
        return 0
      fi
      case "$RUNNER_STATUS" in BLOCKED|UNSUPPORTED) return 3 ;; esac
      case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in verify:*|apply:5) return 5 ;; *) return 1 ;; esac ;;
    *) log_error "Unknown install target: $target"; return 2 ;;
  esac
}
run_workspace() {
  local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
  runner_run workspace && return 0
  case "$RUNNER_STATUS" in
    BLOCKED|UNSUPPORTED) return 3 ;;
    NEEDS_ACTION) return 4 ;;
  esac
  # workspace_configure performs its own path and post-install checks in apply.
  case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in
    check:2) log_error 'Workspace must be a safe directory inside HOME'; return 2 ;;
    apply:2) return 2 ;;
    apply:5|verify:*) return 5 ;;
    *) return 1 ;;
  esac
}
# Bind the CLI/config snapshot once. Legacy adapters still own their individual
# requests and exit-code translations. Runner dispatch never switches on an ID.
run_request() {
  local action=$1 requested=$2 index dry_run=false
  shift 2
  local PROFILE METHOD REPO SCOPE NO_PASSPHRASE
  local NODE_VERSION=$NODE_VERSION PYTHON_VERSION=$PYTHON_VERSION PYTHON_INSTALL_METHOD=$PYTHON_INSTALL_METHOD
  local -a plan_order=() plan_deps=() common_options retry_options
  parse_options "$action" "$requested" "$@" || return 2
  if [[ $METHOD != ssh && $NO_PASSPHRASE == true ]]; then
    log_error '--no-passphrase requires SSH'; return 2
  fi
  planner_build "$requested" || return 2
  local has_repository=false
  for index in ${plan_order[@]+"${plan_order[@]}"}; do
    case ${REGISTRY_IDS[index]} in
      python) python_validate_request "$PYTHON_INSTALL_METHOD" "$PYTHON_VERSION" || return 2 ;;
      repository) has_repository=true ;;
    esac
  done
  if [[ $action == plan || $dry_run == true ]]; then
    planner_print "$PROFILE" "$METHOD" "$NO_PASSPHRASE"
    return $?
  fi

  local RUNNER_PLANNED=1 shell_full_apply=1 shell_target=''
  local identity_profile=$PROFILE identity_scope=$SCOPE identity_repo=$REPO
  local github_profile=$PROFILE github_method=$METHOD github_unencrypted=$NO_PASSPHRASE
  local node_request=$NODE_VERSION python_request=$PYTHON_VERSION python_method=$PYTHON_INSTALL_METHOD
  local repository_profile=$PROFILE repository_method=$METHOD repository_snapshot
  case $requested in
    node|python) shell_full_apply=0; shell_target=$requested ;;
  esac
  if [[ $has_repository == true ]]; then
    repository_snapshot=$(repository_read_list) || return $?
  fi
  common_options=(--environment "$ENVIRONMENT" --profile "$PROFILE" --method "$METHOD")
  if [[ $NO_PASSPHRASE == true ]]; then common_options+=(--no-passphrase); fi
  retry_options=(--environment "$ENVIRONMENT" "$@")
  runner_execute_plan "$action" "$requested"
}
main() {
  local RUNNER_PLANNED=0 shell_full_apply=0 shell_target='' migration_rc=''
  local requested_environment=''
  local -a command=()
  while (( $# )); do
    case "$1" in
      --environment)
        if [[ -n $requested_environment || $# -lt 2 ]]; then
          log_error 'Expected one --environment classroom|minimal'; return 2
        fi
        config_validate_environment "$2" || return 2
        requested_environment=$2
        shift 2 ;;
      --environment=*) log_error 'Use --environment classroom|minimal'; return 2 ;;
      --profile|--method|--version|--repo|--dest|--name)
        # Preserve the original option/value pair for the command parser.
        [[ ${2-} != --environment ]] || { log_error "Missing value for $1"; return 2; }
        command+=("$1"); shift
        if (( $# )); then command+=("$1"); shift; fi ;;
      *) command+=("$1"); shift ;;
    esac
  done
  set -- ${command[@]+"${command[@]}"}
  load_config "$ROOT_DIR" "$requested_environment" || return $?
  local action="${1:-}" target="${2:-}"
  case "$action" in
    '') [[ $# -eq 0 ]] || return 2; menu "$requested_environment" ;;
    help|-h|--help) usage ;;
    doctor)
      if [[ $# -eq 1 ]]; then doctor
      elif [[ "$target" == github ]]; then shift 2; parse_options "$action" "$target" "$@" || return $?; github_doctor "$PROFILE" "$METHOD"
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
    plan|all|check|apply)
      shift
      target=''
      if [[ ( $action == check || $action == apply ) && $# -gt 0 && $1 != --* ]]; then
        target=$1
        [[ -n $target ]] || return 2
        shift
      fi
      run_request "$action" "$target" "$@" ;;
    install)
      [[ $# -ge 2 ]] || { usage; return 2; }
      shift 2; run_install "$target" "$@" ;;
    configure)
      [[ $# -ge 2 ]] || { usage; return 2; }
      if [[ "$target" == workspace ]]; then
        [[ $# -eq 2 ]] || return 2
        run_workspace; return $?
      fi
      if [[ "$target" == shell ]]; then
        [[ $# -eq 2 ]] || { log_error 'Shell accepts no options'; return 2; }
        shell_configure; return $?
      fi
      shift 2; parse_options "$action" "$target" "$@" || return $?
      case "$target" in
        git) [[ "$NO_PASSPHRASE" == false && "$METHOD" == "$DEFAULT_AUTH_METHOD" ]] || { log_error 'Unsupported Git option'; return 2; }; configure_git "$PROFILE" "$SCOPE" "$REPO" ;;
        github) [[ "$SCOPE" == global && -z "$REPO" ]] || { log_error '--repo is not supported for GitHub auth'; return 2; }; configure_github "$PROFILE" "$METHOD" "$NO_PASSPHRASE" ;;
        *) usage; return 2;;
      esac ;;
    *) log_error "Unsupported command: $action"; usage; return 2 ;;
  esac
}
