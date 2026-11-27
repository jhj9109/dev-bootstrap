#!/usr/bin/env bash

usage() {
  cat <<USAGE
Dev Bootstrap v2
Usage:
  ./setup.sh                              Interactive menu
  ./setup.sh doctor                       Read-only environment check
  ./setup.sh plan [--profile personal|secondary] [--method ssh|gh] [--no-passphrase]
  ./setup.sh check [MODULE] [options]
  ./setup.sh apply [MODULE] [options]
  ./setup.sh all [--dry-run] [--profile personal|secondary] [--method ssh|gh] [--no-passphrase]
  ./setup.sh list
  ./setup.sh help

Select an environment for any command or the menu with --environment classroom|minimal.
Default GitHub method: ssh. Default Git identity scope: --global.
--no-passphrase explicitly permits creating an unencrypted SSH private key.
GitHub key registration is manual. The gh method requires a preinstalled gh CLI.
Node uses nvm, Python uses uv by default; source builds require a full X.Y.Z version.

$(registry_command_usage)

Modules for check/apply:
$(registry_list)
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
  local command_index
  if (( $# >= 2 )) && command_index=$(registry_command_index "$1 $2"); then
    shift 2
    "${REGISTRY_COMMAND_HANDLERS[command_index]}" "$@"
    return $?
  fi
  case "$action" in
    '') [[ $# -eq 0 ]] || return 2; menu "$requested_environment" ;;
    help|-h|--help) usage ;;
    doctor) [[ $# -eq 1 ]] || return 2; doctor ;;
    list) [[ $# -eq 1 ]] || return 2; registry_list ;;
    plan|all|check|apply)
      shift
      target=''
      if [[ ( $action == check || $action == apply ) && $# -gt 0 && $1 != --* ]]; then
        target=$1
        [[ -n $target ]] || return 2
        shift
      fi
      run_request "$action" "$target" "$@" ;;
    *) log_error "Unsupported command: $action"; usage; return 2 ;;
  esac
}
