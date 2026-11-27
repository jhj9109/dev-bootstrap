#!/usr/bin/env bash

# Each hook inherits these locals from configure_git through the Runner.
git_identity_context() {
  profile_load "${identity_profile:-}" || return $?
  require_command git || { log_error 'git is required'; return 3; }
  case "${identity_scope:-}" in
    global)
      [[ -z ${identity_repo:-} ]] || return 2
      identity_args=(config --global) ;;
    local)
      [[ -d ${identity_repo:-} ]] || { log_error 'Existing repository path required'; return 2; }
      # An ambient repository override could redirect a write away from --repo.
      if [[ -n ${GIT_DIR:-} || -n ${GIT_WORK_TREE:-} || -n ${GIT_COMMON_DIR:-} ]]; then
        log_error 'Explicit --repo conflicts with Git repository environment'
        return 2
      fi
      local inside
      inside=$(git -C "$identity_repo" rev-parse --is-inside-work-tree) && [[ $inside == true ]] || {
        log_error 'Expected a Git working tree'; return 2
      }
      identity_args=(-C "$identity_repo" config --local) ;;
    *) log_error 'Invalid Git configuration scope'; return 2 ;;
  esac
}

git_identity_check() {
  local -a identity_args
  local key expected value rc result=0
  git_identity_context || return $?
  for key in user.name user.email; do
    case "$key" in user.name) expected=$PROFILE_USER ;; user.email) expected=$PROFILE_EMAIL ;; esac
    rc=0
    # Keep embedded/trailing newlines distinct. Git can also return 1 with a
    # diagnostic for an unreadable file. Only a silent 1 means a missing key.
    value=$(git "${identity_args[@]}" --get-all "$key" 2>&1 && printf '.') || rc=$?
    case "$rc" in
      0) [[ $value == "$expected"$'\n.' ]] || result=10 ;;
      1) [[ -z $value ]] || { log_error "Cannot read $key"; return 1; }; result=10 ;;
      *) log_error "Cannot read $key (git exited $rc)"; return 1 ;;
    esac
  done
  return "$result"
}

git_identity_apply() {
  local -a identity_args
  git_identity_context || return $?
  git "${identity_args[@]}" --replace-all user.name "$PROFILE_USER" || return 1
  git "${identity_args[@]}" --replace-all user.email "$PROFILE_EMAIL" || return 1
}

register_module --id git --name 'Git author' --platforms 'Darwin Linux' \
  --prerequisites 'Git executable and configured account identity.' \
  --check git_identity_check --apply git_identity_apply --verify git_identity_check

git_command_configure() {
  parse_options configure git "$@" || return $?
  [[ $NO_PASSPHRASE == false && $METHOD == "$DEFAULT_AUTH_METHOD" ]] || { log_error 'Unsupported Git option'; return 2; }
  configure_git "$PROFILE" "$SCOPE" "$REPO"
}
register_command 'configure git' git_command_configure '[--profile personal|secondary] [--global | --repo PATH]' 2 'Configure Git identity'
