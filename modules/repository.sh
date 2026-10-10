#!/usr/bin/env bash
repo_parse_spec() {
  local spec="$1"
  [[ "$spec" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && "$spec" != *'..'* ]] || { log_error 'Expected OWNER/REPO (no traversal)'; return 2; }
  REPO_OWNER="${spec%%/*}" REPO_NAME="${spec#*/}"
  [[ "$REPO_OWNER" != '.' && "$REPO_NAME" != '.' ]] || return 2
}
repo_url() {
  local spec="$1" profile="$2" method="$3"
  repo_parse_spec "$spec" || return $?
  case "$method" in
    ssh) printf 'git@github-%s:%s/%s.git\n' "$profile" "$REPO_OWNER" "$REPO_NAME" ;;
    gh) printf 'https://github.com/%s/%s.git\n' "$REPO_OWNER" "$REPO_NAME" ;;
    *) return 2;;
  esac
}
repo_clone() {
  local spec="$1" profile="$2" method="$3" destination="${4:-}" url
  profile_load "$profile" || return $?
  require_command git || return 3
  repo_parse_spec "$spec" || return $?
  url="$(repo_url "$spec" "$profile" "$method")" || return $?
  if [[ -z "$destination" ]]; then
    workspace_configure || return $?
    destination="$WORKSPACE_DIR/$REPO_NAME"
  fi
  [[ "$destination" == /* && "$destination" != / && "$destination" != "$HOME" && "$destination" != "$WORKSPACE_DIR" ]] || { log_error 'Destination must be an absolute non-root directory'; return 2; }
  [[ ! -L "$destination" ]] || { log_error 'Refusing symlink destination'; return 2; }
  if [[ -e "$destination" ]]; then
    [[ -d "$destination/.git" || -f "$destination/.git" ]] || { log_error 'Destination exists and is not a Git repository'; return 1; }
    local existing
    existing="$(git -C "$destination" config --local --get remote.origin.url 2>/dev/null)" || { log_error 'Existing repository has no origin'; return 1; }
    [[ "$existing" == "$url" ]] || { log_error "Existing origin differs: $existing"; return 1; }
    log_ok "Repository already cloned: $destination"; return 0
  fi
  [[ -d "$(dirname "$destination")" ]] || { log_error 'Destination parent does not exist'; return 2; }
  git clone -- "$url" "$destination" || return 1
  [[ "$(git -C "$destination" config --local --get remote.origin.url)" == "$url" ]] || return 5
  log_ok "Cloned $spec to $destination"
}
repo_remote() {
  local path="$1" spec="$2" profile="$3" method="$4" remote="$5" url existing
  profile_load "$profile" || return $?
  [[ -d "$path" && ! -L "$path" ]] || { log_error 'Repository directory required'; return 2; }
  git -C "$path" rev-parse --show-toplevel >/dev/null 2>&1 || { log_error 'Not a Git repository'; return 2; }
  [[ "$remote" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { log_error 'Invalid remote name'; return 2; }
  url="$(repo_url "$spec" "$profile" "$method")" || return $?
  if existing="$(git -C "$path" config --local --get "remote.$remote.url" 2>/dev/null)"; then
    if [[ "$existing" == "$url" ]]; then log_ok "Remote $remote already correct"; return 0; fi
    log_error "Remote $remote already exists with different URL: $existing (not overwritten)"; return 1
  fi
  git -C "$path" remote add "$remote" "$url" || return 1
  [[ "$(git -C "$path" config --local --get "remote.$remote.url")" == "$url" ]] || return 5
  log_ok "Added remote $remote: $url"
}
