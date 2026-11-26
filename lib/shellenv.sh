#!/usr/bin/env bash

shellenv_safe_directory() {
  [[ ! -L $1 && ( ! -e $1 || ( -d $1 && -O $1 && -x $1 ) ) ]]
}

shellenv_safe_file() {
  [[ ! -L $1 && ( ! -e $1 || ( -f $1 && -O $1 && -r $1 ) ) &&
     ! -L $1.zwc && ! -e $1.zwc ]]
}

# Read data only. An invalid list must not be sanitized and overwritten.
shellenv_read_list() {
  local file=$1 name seen=' ' LC_ALL=C
  current=()
  shellenv_safe_file "$file" || return 1
  [[ -e $file ]] || return 0
  if IFS= read -r -d '' name < "$file"; then return 4; fi
  while IFS= read -r name || [[ -n $name ]]; do
    [[ $name =~ ^[a-z][a-z0-9_-]*$ && $seen != *" $name "* ]] || return 4
    current+=("$name")
    seen="$seen$name "
  done < "$file"
}

shellenv_template() {
  if [[ -n $2 ]]; then printf '%s/%s.zsh\n' "$2" "$1"
  else printf '%s/modules/%s/%s.zsh\n' "$ROOT_DIR" "$1" "$1"; fi
}

shellenv_list_text() {
  if (( $# )); then printf '%s\n' "$@"; fi
}

# Receipts identify exact template revisions previously published for this ID.
# A changed user file cannot match merely by retaining a marker in its text.
shellenv_receipt() {
  local digest
  digest=$(git hash-object --stdin < "$2") || return 1
  printf '%s/.managed-%s-%s\n' "${1%/*}" "${1##*/}" "$digest"
}

shellenv_record_template() {
  local receipt
  receipt=$(shellenv_receipt "$1" "$2") || return 1
  if [[ ! -e $receipt && ! -L $receipt ]]; then
    (set -C; : > "$receipt") || return 1
  fi
  [[ ! -L $receipt && -f $receipt && -O $receipt && ! -s $receipt ]]
}

# T14 lists predate receipts. Adopt a valid existing v2 list on its first
# update. Once recorded, refuse to overwrite unrecognized user edits.
shellenv_list_writable() {
  local file=$1 receipt previous
  receipt=$(shellenv_receipt "$file" "$file") || return 1
  [[ ! -L $receipt && -f $receipt && -O $receipt && ! -s $receipt ]] && return 0
  for previous in "${file%/*}"/.managed-active.list-*; do
    if [[ -e $previous || -L $previous ]]; then
      log_warn 'Review edited active.list'; return 4
    fi
  done
  [[ ${generation:-} == v2 ]] || { log_warn 'Review existing active.list'; return 4; }
}

shellenv_fragment_state() {
  local target=$1 template=$2 receipt
  shellenv_safe_file "$target" || return 1
  [[ -f $template && ! -L $template ]] || return 1
  if [[ ${generation:-} == v2 && -n ${shell_target:-} &&
        ${shell_full_apply:-0} == 0 && ${target##*/} != "$shell_target.zsh" ]]; then
    # Individual installs leave every other active file under its owner.
    [[ -f $target ]] || { log_warn "Restore missing active fragment: $target"; return 4; }
    return 0
  fi
  [[ -e $target ]] || return 10
  cmp -s "$target" "$template" && return 0
  receipt=$(shellenv_receipt "$target" "$target") || return 1
  if [[ ! -L $receipt && -O $receipt && -f $receipt && ! -s $receipt ]]; then return 10; fi
  log_warn "Review edited fragment: $target"
  return 4
}

# Prepare all inputs first. Replace only previously published template bytes. Only
# a v2 reconciliation can replace an existing manifest. Publish it last.
shellenv_publish() (
  local source_dir=$1 mode=$2 dir="$HOME/.config/dev-bootstrap" name target template stage file
  local state seen=' ' LC_ALL=C
  shift 2
  shellenv_safe_directory "$dir/env.d" && shellenv_safe_file "$dir/env.d/active.list" || return 1
  umask 077
  stage=$(mktemp -d "$dir/.migration.XXXXXXXX") || return 1
  trap 'rm -rf -- "$stage"' EXIT
  shellenv_list_text "$@" > "$stage/active.list" || return 1
  target="$dir/env.d/active.list"
  if [[ -e $target ]]; then
    cp -p "$target" "$stage/list.old" || return 1
    if ! cmp -s "$target" "$stage/active.list"; then
      [[ $mode == reconcile ]] || { log_warn 'Review conflicting active.list'; return 4; }
      shellenv_list_writable "$target" || return $?
      shellenv_record_template "$target" "$stage/list.old" || return 1
    fi
  fi
  for name in "$@"; do
    [[ $name =~ ^[a-z][a-z0-9_-]*$ && $seen != *" $name "* ]] || return 1
    seen="$seen$name "
    target="$dir/env.d/$name.zsh"
    shellenv_safe_file "$target" || return 1
    template=$(shellenv_template "$name" "$source_dir") || return 1
    if [[ ! -e $template && -z $source_dir && -f $target ]]; then continue; fi
    state=0
    shellenv_fragment_state "$target" "$template" || state=$?
    case $state in
      0) continue ;;
      10)
        [[ $mode != verify ]] || return 4
        if [[ -e $target ]]; then
          [[ $mode == reconcile ]] || return 4
          cp -p "$target" "$stage/$name.old" && cp -p "$stage/$name.old" "$stage/$name.zsh" || return 1
        fi ;;
      *) return "$state" ;;
    esac
    cat "$template" > "$stage/$name.zsh" && zsh -fn "$stage/$name.zsh" || return 1
  done
  if [[ $mode != verify ]]; then mkdir -p "$dir/env.d" || return 1; fi
  for name in "$@"; do
    file="$stage/$name.zsh"
    [[ -f $file ]] || continue
    target="$dir/env.d/$name.zsh"
    shellenv_safe_directory "$dir/env.d" && shellenv_safe_file "$target" || return 1
    shellenv_record_template "$target" "$file" || return 1
    if [[ -e $stage/$name.old ]]; then
      cmp -s "$stage/$name.old" "$target" && mv -f "$file" "$target" || return 1
    else ln "$file" "$target" || return 1; fi
  done
  target="$dir/env.d/active.list"
  shellenv_safe_file "$target" || return 1
  if [[ $mode != verify ]]; then
    shellenv_record_template "$target" "$stage/active.list" || return 1
  fi
  if [[ ! -e $stage/list.old ]]; then
    [[ $mode != verify ]] || return 4
    ln "$stage/active.list" "$target" || return 1
  elif ! cmp -s "$target" "$stage/active.list"; then
    [[ $mode == reconcile ]] || { log_warn 'Review conflicting active.list'; return 4; }
    cmp -s "$target" "$stage/list.old" || return 4
    cp -p "$stage/list.old" "$stage/list.new" && cat "$stage/active.list" > "$stage/list.new" &&
      mv -f "$stage/list.new" "$target" || return 1
  fi
)

# Only a byte-identical v1 can be replaced. Retry reuses prepared fragments.
shellenv_migrate() (
  local source_dir=$1 dir="$HOME/.config/dev-bootstrap" rc="${migration_rc:-$HOME/.zshrc}"
  local templates="$ROOT_DIR/modules/shell" tmp
  shift
  shell_safe_paths && shellenv_safe_file "$dir/env.zsh" || return 1
  [[ $(shell_loader_state "$rc") == ready ]] || return 4
  if cmp -s "$templates/loader.zsh" "$dir/env.zsh"; then
    shellenv_publish "$source_dir" verify "$@"; return $?
  fi
  cmp -s "$templates/env.zsh" "$dir/env.zsh" || { log_warn 'Review edited env.zsh'; return 4; }
  tmp=$(mktemp "$dir/.env.XXXXXXXX") || return 1
  trap 'rm -f -- "$tmp"' EXIT
  cp -p "$dir/env.zsh" "$tmp" && cat "$templates/loader.zsh" > "$tmp" &&
    zsh -fn "$tmp" || return 1
  shellenv_publish "$source_dir" migrate "$@" || return $?
  shell_safe_paths && [[ $(shell_loader_state "$rc") == ready ]] &&
    cmp -s "$templates/env.zsh" "$dir/env.zsh" || return 4
  mv -f "$tmp" "$dir/env.zsh"
)
