#!/usr/bin/env bash
configure_git() {
  local profile="$1" scope="$2" repo="$3"
  profile_load "$profile" || return $?
  require_command git || { log_error 'git is required'; return 3; }
  local args=()
  case "$scope" in
    global) args=(config --global) ;;
    local)
      [[ -n "$repo" && -d "$repo" ]] || { log_error 'Existing repository path required'; return 2; }
      git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { log_error 'Not a Git repository'; return 2; }
      args=(-C "$repo" config --local) ;;
    *) return 2;;
  esac
  git "${args[@]}" user.name "$PROFILE_USER" || return 1
  git "${args[@]}" user.email "$PROFILE_EMAIL" || return 1
  [[ "$(git "${args[@]}" user.name)" == "$PROFILE_USER" && "$(git "${args[@]}" user.email)" == "$PROFILE_EMAIL" ]] || return 5
  log_ok "Git $scope identity configured for $profile"
}
