#!/usr/bin/env bash

# Produce the validated list once so all three hooks restore the same request.
repository_read_list() {
  local file="$ROOT_DIR/config/repositories.conf" contents line name seen=' ' number=0
  [[ -e $file || -L $file ]] || return 0
  [[ -f $file && -r $file && ! -L $file ]] || { log_error 'Cannot read repository list'; return 1; }
  # Bash strings cannot represent a NUL. Make it an invalid spec character.
  contents=$(LC_ALL=C tr '\000' '!' < "$file") || return 1
  while IFS= read -r line; do
    number=$((number+1))
    line=${line%%#*}
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [[ -n $line ]] || continue
    repo_valid_spec "$line" || { log_error "Invalid repository at line $number"; return 2; }
    # Default macOS volumes are case-insensitive. Reject collisions on all hosts.
    name=$(printf '%s' "${line#*/}" | LC_ALL=C tr 'A-Z' 'a-z') || return 1
    if [[ $name == .git || $seen == *" $name "* ]]; then
      log_error "Reserved or duplicate repository destination at line $number"; return 2
    fi
    seen="$seen$name "
    printf '%s\n' "$line" || return 1
  done <<< "$contents"
}

repository_check() {
  local list=${repository_snapshot-} spec url rc result=0
  local profile=${repository_profile:-$DEFAULT_GITHUB_PROFILE} method=${repository_method:-$DEFAULT_AUTH_METHOD}
  if [[ ! ${repository_snapshot+x} ]]; then list=$(repository_read_list) || return $?; fi
  [[ -n $list ]] || return 0
  repo_context "$profile" || return $?
  while IFS= read -r spec; do
    url=$(repo_url "$spec" "$profile" "$method") || return $?
    rc=0
    repo_clone_status "$WORKSPACE_DIR/${spec#*/}" "$url" true || rc=$?
    case "$rc" in
      0) ;;
      10) result=10 ;;
      *) log_error "Cannot restore $spec"; return "$rc" ;;
    esac
  done <<< "$list"
  return "$result"
}

repository_apply() {
  local list=${repository_snapshot-} spec rc=0 failure=0
  if [[ ! ${repository_snapshot+x} ]]; then list=$(repository_read_list) || return $?; fi
  local repository_snapshot=$list
  repository_check || rc=$?
  [[ $rc == 10 ]] || return "$rc"
  while IFS= read -r spec; do
    repo_clone "$spec" "${repository_profile:-$DEFAULT_GITHUB_PROFILE}" "${repository_method:-$DEFAULT_AUTH_METHOD}" || {
      rc=$?
      log_error "Restore failed for $spec"
      if [[ $failure == 0 ]]; then failure=$rc; fi
    }
  done <<< "$list"
  return "$failure"
}

register_module --id repository --name Repository --platforms 'Darwin Linux' --depends workspace \
  --check repository_check --apply repository_apply --verify repository_check
