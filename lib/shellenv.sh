#!/usr/bin/env bash
# Internal v1 migration. The caller supplies a trusted template directory and
# ordered fragment IDs. The default configure/install path stays on v1 until T15.
shellenv_migrate() (
  local source_dir=$1 dir="$HOME/.config/dev-bootstrap" rc="$HOME/.zshrc"
  local templates="$ROOT_DIR/modules/shell" name file stage seen=' ' LC_ALL=C
  local -a files
  shift
  shell_safe_paths || return 1
  [[ -f $rc && $(shell_loader_state "$rc") == ready ]] || {
    log_warn 'Review .zshrc before migrating the shell'; return 4
  }
  local migrated=0
  if cmp -s "$templates/loader.zsh" "$dir/env.zsh"; then
    migrated=1
  elif ! cmp -s "$templates/env.zsh" "$dir/env.zsh"; then
    log_warn 'Review edited or missing env.zsh before migration'; return 4
  fi
  [[ ! -L $dir/env.d && ( ! -e $dir/env.d || ( -d $dir/env.d && -O $dir/env.d ) ) &&
     ! -e $dir/env.zsh.zwc && ! -L $dir/env.zsh.zwc ]] || return 1

  command -v zsh >/dev/null || { log_error 'Migration requires zsh for syntax checks'; return 1; }
  umask 077
  stage=$(mktemp -d "$dir/.migration.XXXXXXXX") || return 1
  trap 'rm -rf -- "$stage"' EXIT
  : > "$stage/active.list" || return 1
  for name in "$@"; do
    [[ $name =~ ^[a-z][a-z0-9_-]*$ && $seen != *" $name "* ]] || return 1
    seen="$seen$name "
    files+=("$name.zsh")
    file="$source_dir/$name.zsh"
    [[ -f $file && ! -L $file ]] || return 1
    cat "$file" > "$stage/$name.zsh" && zsh -fn "$stage/$name.zsh" &&
      printf '%s\n' "$name" >> "$stage/active.list" || return 1
  done
  # Preserve the old loader mode. Publish complete files without overwriting
  # conflicts. Identical files from an interrupted attempt can be reused.
  cp -p "$dir/env.zsh" "$stage/env.new" &&
    cat "$templates/loader.zsh" > "$stage/env.new" || return 1
  zsh -fn "$stage/env.new" || return 1
  if (( ! migrated )); then mkdir -p "$dir/env.d" || return 1; fi
  files+=(active.list)
  local target
  for name in "${files[@]}"; do
    file="$stage/$name"
    target="$dir/env.d/$name"
    [[ ! -L $target && ! -e $target.zwc && ! -L $target.zwc ]] || return 1
    if [[ ! -e $target && $migrated == 0 ]]; then
      # A concurrent migration may have just published the same file.
      ln "$file" "$target" || [[ -f $target ]] || return 1
    fi
    [[ -f $target && -O $target && ! -L $target ]] && cmp -s "$target" "$file" || {
      log_warn "Review conflicting shell file: $target"; return 4
    }
  done
  shell_safe_paths && [[ $(shell_loader_state "$rc") == ready ]] || return 1
  cmp -s "$stage/env.new" "$dir/env.zsh" && return 0
  cmp -s "$templates/env.zsh" "$dir/env.zsh" || return 4
  mv -f "$stage/env.new" "$dir/env.zsh"
)
