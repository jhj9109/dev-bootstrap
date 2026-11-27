#!/usr/bin/env bash

python_defaults() {
  PYTHON_VERSION=3.12
  PYTHON_INSTALL_METHOD=uv
}

python_validate() {
  case "$PYTHON_INSTALL_METHOD" in uv|source) ;; *) log_error 'Invalid Python method'; return 2 ;; esac
  [[ $PYTHON_VERSION =~ ^[0-9]+[.][0-9]+([.][0-9]+)?$ ]] || { log_error 'Invalid Python version'; return 2; }
}

python_inspect() {
  local prefix="$HOME/.local/python-$version" cmd
  python_validate_request "$method" "$version" || return $?
  case "$method" in
    source)
      python_safe_directories "$HOME" "$HOME/.local" "$prefix" || return 1
      if [[ -e $prefix ]]; then
        python_source_probe "$prefix" || { log_error 'Review existing Python installation'; return 1; }
        return 0
      fi
      for cmd in curl tar make; do require_command "$cmd" || { log_error "Missing $cmd"; return 3; }; done
      return 10 ;;
    uv)
      shell_state=0
      shell_runtime_status || shell_state=$?
      case "$shell_state" in 0|10) ;; *) return "$shell_state" ;; esac
      uv_state=0
      python_uv_status || uv_state=$?
      [[ $uv_state == 0 ]] || return "$uv_state"
      return "$shell_state" ;;
    *) return 2 ;;
  esac
}

python_check() {
  local shell_target=python
  local version=${python_request:-$PYTHON_VERSION} method=${python_method:-$PYTHON_INSTALL_METHOD}
  local uv="$HOME/.local/bin/uv" shell_state uv_state
  python_inspect
}

python_apply() {
  local shell_target=python
  local version=${python_request:-$PYTHON_VERSION} method=${python_method:-$PYTHON_INSTALL_METHOD}
  local uv="$HOME/.local/bin/uv" shell_state uv_state rc=0
  python_inspect || rc=$?
  [[ $rc == 10 ]] || return "$rc"
  if [[ $method == source ]]; then python_source_install; return $?; fi
  if [[ ! -e $uv ]]; then
    python_bootstrap_uv || return 1
    [[ -x $uv ]] || return 1
    uv_state=0
    python_uv_status || uv_state=$?
  fi
  case "$uv_state" in
    0) ;;
    10)
      "$uv" python install "$version" || return 1
      # Do not publish shell changes for a failed or incomplete installation.
      if [[ $shell_state == 10 ]]; then python_uv_status || return 5; fi ;;
    *) return "$uv_state" ;;
  esac
  if [[ $shell_state == 10 ]]; then shell_configure || return 1; fi
}

register_module --id python --name Python --platforms 'Darwin Linux' \
  --depends shell --depends-if 'PYTHON_INSTALL_METHOD=uv' \
  --keys 'PYTHON_VERSION PYTHON_INSTALL_METHOD' --defaults python_defaults --validate python_validate \
  --prerequisites 'uv bootstrap needs curl. A source build needs a full X.Y.Z version, curl, tar, make and a C toolchain.' \
  --check python_check --apply python_apply --verify python_check

python_command_install() {
  parse_install_options "$@" || return $?
  local python_request="${INSTALL_VERSION:-$PYTHON_VERSION}" python_method="$INSTALL_METHOD"
  local RUNNER_STATUS RUNNER_PHASE RUNNER_HOOK_STATUS
  python_validate_request "$python_method" "$python_request" || return $?
  runner_run python && return 0
  case "$RUNNER_PHASE:$RUNNER_HOOK_STATUS" in
    verify:*|apply:5) return 5 ;;
    check:2|apply:2) return 2 ;;
    check:3|apply:3) return 3 ;;
    *) return 1 ;;
  esac
}
register_command 'install python' python_command_install '[--version X.Y.Z] [--method uv|source]' 6 'Install Python'
