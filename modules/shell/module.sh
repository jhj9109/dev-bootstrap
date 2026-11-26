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

# check and apply both inspect before modifying either file.
shell_inspect() {
  local template="$ROOT_DIR/modules/shell/env.zsh" managed="$HOME/.config/dev-bootstrap/env.zsh" rc=0
  shell_safe_paths || return 1
  [[ -f $template && -r $template ]] || { log_error 'Cannot read env.zsh template'; return 1; }
  if [[ -e $managed ]]; then
    cmp -s "$template" "$managed" || rc=$?
    case "$rc" in
      0) ;;
      1) log_warn 'Review edited env.zsh before configuring the shell'; return 4 ;;
      *) log_error 'Cannot compare env.zsh'; return 1 ;;
    esac
  fi
  loader_state=absent
  if [[ -e $HOME/.zshrc ]]; then
    loader_state=$(shell_loader_state "$HOME/.zshrc") || { log_error 'Cannot read .zshrc'; return 1; }
  fi
  case "$loader_state" in
    ready) [[ -e $managed ]] && return 0 ;;
    absent|marker) ;;
    *) log_warn 'Review ambiguous dev-bootstrap loader in .zshrc'; return 4 ;;
  esac
  return 10
}

shell_check() {
  local loader_state
  shell_inspect
}

shell_apply() (
  local dir="$HOME/.config/dev-bootstrap" rc="$HOME/.zshrc"
  local loader_state status=0 tmp_env='' tmp_rc='' original='' last
  shell_inspect || status=$?
  [[ $status == 10 ]] || return "$status"
  umask 077
  trap '[[ -z $tmp_env ]] || rm -f -- "$tmp_env"; [[ -z $tmp_rc ]] || rm -f -- "$tmp_rc"; [[ -z $original ]] || rm -f -- "$original"' EXIT

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
  if [[ ! -e $dir/env.zsh ]]; then
    mkdir -p "$dir" || return 1
    tmp_env=$(mktemp "$dir/.env.XXXXXXXX") || return 1
    cat "$ROOT_DIR/modules/shell/env.zsh" > "$tmp_env" || return 1
    cmp -s "$ROOT_DIR/modules/shell/env.zsh" "$tmp_env" || return 1
    # A hard link publishes the complete file only if its name is still free.
    ln "$tmp_env" "$dir/env.zsh" || return 1
  fi
  if [[ -n $tmp_rc ]]; then
    shell_safe_paths || return 1
    cmp -s "$ROOT_DIR/modules/shell/env.zsh" "$dir/env.zsh" || return 1
    if [[ -n $original ]]; then
      cmp -s "$original" "$rc" || { log_error '.zshrc changed during setup'; return 1; }
      mv -f "$tmp_rc" "$rc" || return 1
    else
      ln "$tmp_rc" "$rc" || return 1
    fi
  fi
)

register_module --id shell --name Shell --platforms 'Darwin Linux' \
  --check shell_check --apply shell_apply --verify shell_check
