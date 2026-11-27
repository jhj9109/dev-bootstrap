#!/usr/bin/env bash

repo_valid_spec() {
  local LC_ALL=C spec=$1
  [[ $spec =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && $spec != *'..'* &&
     ${spec%%/*} != . && ${spec#*/} != . ]] || { log_error 'Expected OWNER/REPO'; return 2; }
}

repo_url() {
  local spec=$1
  repo_valid_spec "$spec" || return 2
  case "$3" in
    ssh) printf 'git@github-%s:%s.git\n' "$2" "$spec" ;;
    gh) printf 'https://github.com/%s.git\n' "$spec" ;;
    *) return 2 ;;
  esac
}

repo_context() {
  local var
  profile_load "$1" || return $?
  require_command git || { log_error 'Git is required'; return "${2:-3}"; }
  # git -C alone does not isolate a checkout from repository/config overrides.
  for var in GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS \
      GIT_SHALLOW_FILE GIT_GRAFT_FILE GIT_IMPLICIT_WORK_TREE GIT_NAMESPACE GIT_QUARANTINE_PATH; do
    [[ -z ${!var+x} ]] || { log_error "Repository operation conflicts with $var"; return 2; }
  done
}

# Walk before folding ".." so an intermediate symlink cannot disappear during
# normalization. Missing components are allowed for a future default Workspace.
repo_path() {
  local rest=$1 path='' part
  [[ $rest == /* && $rest != *[$'\r\n']* ]] || return 2
  while [[ -n $rest ]]; do
    rest=${rest#/}
    part=${rest%%/*}
    if [[ $rest == */* ]]; then rest=${rest#*/}; else rest=''; fi
    [[ ! -e ${path:-/} || ( -d ${path:-/} && -x ${path:-/} ) ]] || return 2
    case "$part" in
      ''|.) continue ;;
      ..) [[ -d ${path:-/} ]] || return 2; path=${path%/*} ;;
      *) path="$path/$part"; [[ ! -L $path ]] || return 2 ;;
    esac
  done
  printf '%s\n' "${path:-/}"
}

repo_worktree() {
  local path=$1 top gitdir common backlink
  [[ ! -L $path/.git && ( -d $path/.git || -f $path/.git ) ]] || return 1
  top=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null) && [[ $top -ef $path ]] || return 1
  gitdir=$(git -C "$path" rev-parse --absolute-git-dir 2>/dev/null) || return 1
  common=$(git -C "$path" rev-parse --git-common-dir 2>/dev/null) || return 1
  [[ $common == /* ]] || common="$path/$common"
  repo_path "$gitdir" >/dev/null && repo_path "$common/config" >/dev/null && [[ -f $common/config ]] || return 1
  if [[ -d $path/.git ]]; then
    [[ $common -ef $path/.git ]] || return 1
  elif [[ -f $gitdir/gitdir && ! -L $gitdir/gitdir ]]; then
    # Linked worktrees have a backlink in the common repository's worktrees/.
    [[ $gitdir/.. -ef $common/worktrees ]] && IFS= read -r backlink < "$gitdir/gitdir" || return 1
    [[ $backlink == /* ]] || backlink="$gitdir/$backlink"
    [[ $backlink -ef $path/.git ]] || return 1
  else
    # Submodules record their worktree explicitly. A copied gitfile alone
    # cannot authorize changes to another checkout's config.
    backlink=$(git -C "$path" config --local --get core.worktree 2>/dev/null) && [[ -n $backlink ]] || return 1
    [[ $backlink == /* ]] || backlink="$gitdir/$backlink"
    [[ $backlink -ef $path ]] || return 1
  fi
}

# 0 = exactly one matching raw URL, 10 = absent, 1 = conflict/query error.
# Do not log Git diagnostics or a stored URL (either may contain credentials).
repo_remote_status() {
  local path=$1 remote=$2 expected=$3 scope value rc missing=false
  local -a args
  for scope in local effective; do
    args=(config)
    if [[ $scope == local ]]; then args+=(--local); fi
    rc=0
    value=$(git -C "$path" "${args[@]}" --includes --get-all "remote.$remote.url" 2>&1 && printf .) || rc=$?
    if [[ $rc == 1 && -z $value ]]; then
      [[ $scope == local || $missing == true ]] || { log_error "Cannot resolve remote $remote"; return 1; }
      missing=true
      continue
    fi
    [[ $rc == 0 ]] || { log_error "Cannot read remote $remote"; return 1; }
    [[ $missing == false && $value == "$expected"$'\n.' ]] || {
      log_error "Remote $remote has a different or ambiguous URL"; return 1
    }
  done
  if [[ $missing == true ]]; then return 10; fi
  return 0
}

# With a default destination, missing Workspace parents can be created in apply.
repo_clone_status() {
  local path=$1 url=$2 default=$3 rc=0 parent=${1%/*} reserved_workspace
  repo_path "$path" >/dev/null || { log_error 'Unsafe destination path'; return 2; }
  if [[ $default == true ]]; then
    workspace_validate_path || return $?
  fi
  reserved_workspace=$(repo_path "$WORKSPACE_DIR") || reserved_workspace=''
  if [[ $path =~ /\.[gG][iI][tT](/|$) || $path == / || $path == "$HOME" || $path == "$reserved_workspace" ||
        $path -ef "$HOME" || $path -ef "$WORKSPACE_DIR" ]]; then
    log_error 'Refusing reserved destination'; return 2
  fi
  if [[ ! -e $path ]]; then
    [[ $default == true || -d ${parent:-/} ]] || { log_error 'Destination parent does not exist'; return 2; }
    return 10
  fi
  repo_worktree "$path" || { log_error 'Destination is not a valid Git worktree root'; return 1; }
  repo_remote_status "$path" origin "$url" || rc=$?
  if [[ $rc == 10 ]]; then log_error 'Existing repository has no origin URL'; return 1; fi
  return "$rc"
}

repo_clone() (
  local spec=$1 profile=$2 method=$3 path url parent stage name rc=0 default=false
  repo_context "$profile" || return $?
  url=$(repo_url "$spec" "$profile" "$method") || return $?
  [[ -n ${4:-} ]] || default=true
  path=$(repo_path "${4:-$WORKSPACE_DIR/${spec#*/}}") || { log_error 'Unsafe destination path'; return 2; }
  repo_clone_status "$path" "$url" "$default" || rc=$?
  if [[ $rc == 0 ]]; then log_ok "Repository already cloned: $path"; return 0; fi
  [[ $rc == 10 ]] || return "$rc"
  if [[ $default == true ]]; then
    if [[ ${RUNNER_PLANNED:-0} == 1 ]]; then
      workspace_check || { log_error 'Workspace prerequisite needs changes'; return 3; }
    else
      workspace_configure || return $?
    fi
  fi
  parent=${path%/*}
  parent=${parent:-/}
  name=${path##*/}
  cd -P -- "$parent" && [[ $PWD == "$parent" ]] || return 2
  stage=$(mktemp -d .dev-bootstrap-clone.XXXXXXXX) || return 1
  trap 'rm -rf -- "$stage"' EXIT
  git clone -- "$url" "$stage/$name" >/dev/null 2>&1 || { log_error "Clone failed for $spec"; return 1; }
  repo_clone_status "$PWD/$stage/$name" "$url" false || { log_error 'Cloned repository failed verification'; return 5; }
  repo_path "$path" >/dev/null && [[ . -ef "$parent" && ! -e $path ]] || return 1
  # Naming the parent as mv's directory operand prevents nesting in a
  # concurrent arrival. BSD/GNU mv -n may return success even when skipped.
  mv -n "$stage/$name" . && [[ ! -e $stage/$name ]] || return 1
  repo_clone_status "$path" "$url" "$default" || return 5
  log_ok "Cloned $spec to $path"
)

repo_remote() {
  local path=$1 spec=$2 profile=$3 method=$4 remote=$5 url remotes rc=0
  repo_context "$profile" 2 || return $?
  [[ $path == /* ]] || path="$PWD/$path"
  path=$(repo_path "$path") && repo_worktree "$path" || { log_error 'Valid repository directory required'; return 2; }
  [[ $remote =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { log_error 'Invalid remote name'; return 2; }
  url=$(repo_url "$spec" "$profile" "$method") || return $?
  repo_remote_status "$path" "$remote" "$url" || rc=$?
  if [[ $rc == 0 ]]; then log_ok "Remote $remote already correct"; return 0; fi
  [[ $rc == 10 ]] || return "$rc"
  remotes=$(git -C "$path" remote 2>/dev/null) || { log_error 'Cannot list Git remotes'; return 1; }
  if [[ $'\n'$remotes$'\n' == *$'\n'"$remote"$'\n'* ]]; then
    log_error "Remote $remote exists without a local URL"; return 1
  fi
  git -C "$path" remote add "$remote" "$url" >/dev/null 2>&1 || { log_error "Cannot add remote $remote"; return 1; }
  repo_remote_status "$path" "$remote" "$url" || return 5
  log_ok "Added remote $remote"
}
