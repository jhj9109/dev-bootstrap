#!/usr/bin/env bash

shell_marker() { printf '%s' '# Dev Bootstrap managed environment'; }
shell_loader() { printf '%s' '[ -f "$HOME/.config/dev-bootstrap/env.zsh" ] && . "$HOME/.config/dev-bootstrap/env.zsh"'; }

shell_safe_paths() {
  local path
  for path in "$HOME" "$HOME/.config" "$HOME/.config/dev-bootstrap"; do
    if [[ -L $path || ( -e $path && ( ! -d $path || ! -O $path || ! -x $path ) ) ]]; then
      log_error "Unsafe shell configuration directory: $path"; return 1
    fi
  done
  for path in "$HOME/.zshrc" "$HOME/.config/dev-bootstrap/env.zsh"; do
    if [[ -L $path || ( -e $path && ( ! -f $path || ! -O $path || ! -r $path ) ) ]]; then
      log_error "Cannot safely read $path"; return 1
    fi
  done
}

# Classify only the literal v1 block. Other references may be user-owned.
shell_loader_state() {
  LC_ALL=C awk -v marker="$(shell_marker)" -v loader="$(shell_loader)" '
    $0 == marker { markers++; marker_line=NR; next }
    $0 == loader { loaders++; loader_line=NR; next }
    index($0, marker) || index($0, "dev-bootstrap/env.zsh") { ambiguous=1 }
    END {
      if (ambiguous) print "conflict"
      else if (!markers && !loaders) print "absent"
      else if (markers == 1 && loaders == 1 && loader_line == marker_line + 1) print "ready"
      else if (markers == 1 && !loaders && marker_line == NR) print "marker"
      else print "conflict"
    }' "$1"
}

# desired/current, generation and loader_state belong to the invoking hook.
shell_inspect() {
  local dir="$HOME/.config/dev-bootstrap" templates="$ROOT_DIR/modules/shell"
  local id file template state changed=0 append
  shell_safe_paths && shellenv_safe_file "$dir/env.zsh" &&
    shellenv_safe_directory "$dir/env.d" || return 1
  generation=new
  if [[ -e $dir/env.zsh ]]; then
    if cmp -s "$templates/loader.zsh" "$dir/env.zsh"; then generation=v2
    elif cmp -s "$templates/env.zsh" "$dir/env.zsh"; then generation=v1
    else log_warn 'Review edited env.zsh before configuring the shell'; return 4; fi
  fi
  loader_state=absent
  if [[ -e $HOME/.zshrc ]]; then
    loader_state=$(shell_loader_state "$HOME/.zshrc") || return 1
  fi
  case $loader_state in
    absent|marker|ready) ;;
    *) log_warn 'Review ambiguous dev-bootstrap loader in .zshrc'; return 4 ;;
  esac
  shellenv_read_list "$dir/env.d/active.list" || { log_warn 'Review unsafe or invalid active.list'; return 4; }
  desired=()
  if [[ -n ${shell_target:-} && ${shell_full_apply:-0} == 0 ]]; then
    # v1 initialized both tools. Preserve that behavior on individual installs.
    if [[ $generation == v1 && ! -e $dir/env.d/active.list ]]; then current=(node python); fi
    desired=(${current[@]+"${current[@]}"})
    append=1
    for id in ${current[@]+"${current[@]}"}; do
      [[ $id != "$shell_target" ]] || append=0
    done
    if (( append )); then desired+=("$shell_target"); fi
  else
    for id in ${ENABLED_MODULES[@]+"${ENABLED_MODULES[@]}"}; do
      case $id in
        node) desired+=(node) ;;
        python) [[ $PYTHON_INSTALL_METHOD != uv ]] || desired+=(python) ;;
      esac
    done
  fi
  for id in ${desired[@]+"${desired[@]}"}; do
    file="$dir/env.d/$id.zsh"
    shellenv_safe_file "$file" || return 1
    template=$(shellenv_template "$id" '') || return 1
    if [[ ! -f $template ]]; then
      [[ -f $file && $id != node && $id != python ]] || return 1
    else
      state=0
      shellenv_fragment_state "$file" "$template" || state=$?
      case $state in 0) ;; 10) changed=1 ;; *) return "$state" ;; esac
    fi
  done
  [[ $generation == v2 && $loader_state == ready && $changed == 0 &&
     -f $dir/env.d/active.list ]] || return 10
  cmp -s "$dir/env.d/active.list" <(shellenv_list_text ${desired[@]+"${desired[@]}"}) && return 0
  shellenv_list_writable "$dir/env.d/active.list" || return $?
  return 10
}

shell_check() {
  local loader_state generation
  local -a current desired
  shell_inspect
}

shell_apply() (
  local dir="$HOME/.config/dev-bootstrap" rc="$HOME/.zshrc"
  local loader_state generation status=0 tmp_env='' tmp_rc='' original='' last
  local -a current desired
  shell_inspect || status=$?
  [[ $status == 10 ]] || return "$status"
  umask 077
  mkdir -p "$dir" || return 1
  mkdir "$dir/.shell-update" || { log_error 'Another shell update holds .shell-update'; return 1; }
  trap 'rmdir "$dir/.shell-update"; [[ -z $tmp_env ]] || rm -f -- "$tmp_env"; [[ -z $tmp_rc ]] || rm -f -- "$tmp_rc"; [[ -z $original ]] || rm -f -- "$original"' EXIT
  status=0
  shell_inspect || status=$?
  [[ $status == 10 ]] || return "$status"

  if [[ $loader_state != ready ]]; then
    tmp_rc=$(mktemp "$HOME/.zshrc.XXXXXXXX") || return 1
    if [[ -e $rc ]]; then
      [[ -w $rc && -O $rc ]] || { log_error 'Cannot update .zshrc'; return 1; }
      original=$(mktemp "$HOME/.zshrc.original.XXXXXXXX") || return 1
      cp -p "$rc" "$original" && cp -p "$original" "$tmp_rc" || return 1
      loader_state=$(shell_loader_state "$original") || return 1
    fi
    case "$loader_state" in
      absent) printf '\n%s\n%s\n' "$(shell_marker)" "$(shell_loader)" >> "$tmp_rc" || return 1 ;;
      marker)
        last=$(tail -c 1 "$tmp_rc") || return 1
        if [[ -n $last ]]; then printf '\n' >> "$tmp_rc" || return 1; fi
        printf '%s\n' "$(shell_loader)" >> "$tmp_rc" || return 1 ;;
      *) log_error '.zshrc changed during setup'; return 1 ;;
    esac
  fi

  shell_safe_paths || return 1
  case $generation in
    v1)
      local migration_rc=${tmp_rc:-$rc}
      shellenv_migrate '' ${desired[@]+"${desired[@]}"} || return $? ;;
    new)
      tmp_env=$(mktemp "$dir/.env.XXXXXXXX") || return 1
      cat "$ROOT_DIR/modules/shell/loader.zsh" > "$tmp_env" && zsh -fn "$tmp_env" || return 1
      shellenv_publish '' reconcile ${desired[@]+"${desired[@]}"} || return $?
      ln "$tmp_env" "$dir/env.zsh" || return 1 ;;
    v2) shellenv_publish '' reconcile ${desired[@]+"${desired[@]}"} || return $? ;;
  esac
  if [[ -n $tmp_rc ]]; then
    shell_safe_paths || return 1
    cmp -s "$ROOT_DIR/modules/shell/loader.zsh" "$dir/env.zsh" || return 1
    if [[ -n $original ]]; then
      cmp -s "$original" "$rc" || { log_error '.zshrc changed during setup'; return 1; }
      mv -f "$tmp_rc" "$rc" || return 1
    else
      ln "$tmp_rc" "$rc" || return 1
    fi
  fi
)

register_module --id shell --name Shell --platforms 'Darwin Linux' \
  --prerequisites 'Publishing the loader needs zsh; managing fragment revisions uses Git.' \
  --check shell_check --apply shell_apply --verify shell_check

shell_command_configure() {
  [[ $# == 0 ]] || { log_error 'Shell accepts no options'; return 2; }
  shell_configure
}
register_command 'configure shell' shell_command_configure '' 8 'Configure zsh'
