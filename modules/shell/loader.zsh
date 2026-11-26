# Managed by Dev Bootstrap. Fragments call this helper for their own PATH entry.
dev_bootstrap_path_prepend() {
  emulate -L zsh
  [[ $# == 1 && -n $1 && $1 != *:* ]] || return 1
  local entry found=0 duplicates=0
  local -a kept
  for entry in "${path[@]}"; do
    if [[ $entry == "$1" ]]; then
      if (( found )); then duplicates=1; continue; fi
      found=1
    fi
    kept+=("$entry")
  done
  if (( ! found )); then path=("$1" "${path[@]}")
  elif (( duplicates )); then path=("${kept[@]}")
  fi
}

# Validate the entire ordered list before running any fragment.
() {
  emulate -L zsh
  setopt extendedglob
  local dir="$HOME/.config/dev-bootstrap/env.d" item name seen=' ' LC_ALL=C
  local -a active
  for item in "$HOME" "$HOME/.config" "${dir:h}" "$dir"; do
    [[ -d $item && -O $item && ! -L $item ]] || return 1
  done
  [[ -f $dir/active.list && -O $dir/active.list && ! -L $dir/active.list ]] || return 1
  while IFS= read -r name || [[ -n $name ]]; do
    [[ $name == [a-z][a-z0-9_-]# && $seen != *" $name "* ]] || return 1
    item="$dir/$name.zsh"
    [[ -f $item && -r $item && -O $item && ! -L $item ]] || return 1
    [[ ! -e $item.zwc && ! -L $item.zwc ]] || return 1
    seen+="$name "
    active+=("$item")
  done < "$dir/active.list" || return 1
  for item in "${active[@]}"; do
    builtin source "$item" || return 1
  done
}
