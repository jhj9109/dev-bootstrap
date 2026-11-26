#!/usr/bin/env bash
set -eu
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT_DIR/lib/logger.sh"
register_module() { :; }
source "$ROOT_DIR/modules/shell/module.sh"
source "$ROOT_DIR/lib/shellenv.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home space"
dir="$HOME/.config/dev-bootstrap"
src="$tmp/templates"
mkdir -p "$dir" "$src" "$HOME/.nvm"
v1="$ROOT_DIR/modules/shell/env.zsh"
envfile="$dir/env.zsh"
printf 'export USER_SETTING=keep\n%s\n%s\n' "$(shell_marker)" "$(shell_loader)" > "$HOME/.zshrc"
chmod 640 "$HOME/.zshrc"
ln "$HOME/.zshrc" "$tmp/original-rc"
cp "$HOME/.zshrc" "$tmp/rc-text"
cp "$v1" "$envfile"
chmod 640 "$envfile"
migrate() { shellenv_migrate "$src" "$@"; }
reject() { if "$@"; then echo "Unexpected success: $*" >&2; exit 1; fi; }
if ! command -v zsh >/dev/null; then
  reject migrate
  cmp "$v1" "$envfile"
  echo 'NOT RUN: zsh migration and loader (zsh unavailable)'
  exit 0
fi
printf 'export LEGACY=yes\n' > "$HOME/.nvm/nvm.sh"
legacy_works() {
  cmp "$v1" "$envfile"
  zsh -fc 'source "$HOME/.zshrc" && [[ $LEGACY == yes && $USER_SETTING == keep && $path[1] == "$HOME/.local/bin" ]]'
}
echo 'export ORDER="${ORDER-}B"' > "$src/b.zsh"
cat > "$src/a.zsh" <<'FRAGMENT'
export ORDER="${ORDER-}A"
dev_bootstrap_path_prepend "$HOME/bin"
FRAGMENT
echo 'edited by user' >> "$envfile"
reject migrate b a
grep -q 'edited by user' "$envfile"
cp "$v1" "$envfile"
reject migrate ../b
reject migrate b b
reject migrate b missing
echo 'if then' > "$src/broken.zsh"
reject migrate broken
mv "$envfile" "$tmp/original-env"
ln -s "$tmp/original-env" "$envfile"
reject migrate b a
rm "$envfile"
mv "$tmp/original-env" "$envfile"
mv "$HOME/.zshrc" "$tmp/user-rc"
ln -s "$tmp/user-rc" "$HOME/.zshrc"
reject migrate b a
rm "$HOME/.zshrc"
mv "$tmp/user-rc" "$HOME/.zshrc"
mkdir "$tmp/outside"
ln -s "$tmp/outside" "$dir/env.d"
reject migrate b a
rm "$dir/env.d"
mkdir "$dir/env.d"
ln -s "$tmp/outside/list" "$dir/env.d/active.list"
reject migrate b a
[[ ! -e $tmp/outside/list ]]
rm "$dir/env.d/active.list"
legacy_works

# Fail the final rename after all inputs are ready, then retry the same plan.
mv() { return 1; }
reject migrate b a
legacy_works
unset -f mv
migrate b a
ln "$envfile" "$tmp/new-inode"
migrate b a
[[ $envfile -ef $tmp/new-inode && $HOME/.zshrc -ef $tmp/original-rc ]]
cmp "$tmp/rc-text" "$HOME/.zshrc"
mode=$(stat -c %a "$envfile" 2>/dev/null || stat -f %Lp "$envfile")
[[ $mode == 640 ]]
list="$dir/env.d/active.list"
printf 'b\na\n' > "$tmp/list"
cmp "$list" "$tmp/list"
echo 'export UNEXPECTED=yes' > "$dir/env.d/extra.zsh"
zsh -fc '
  PATH=":${HOME}/bin:other:${HOME}/bin:other:"
  source "$HOME/.zshrc" && source "$HOME/.zshrc" &&
    [[ $ORDER == BABA && $USER_SETTING == keep && -z ${UNEXPECTED-} && $PATH == ":${HOME}/bin:other:other:" ]] &&
    dev_bootstrap_path_prepend "/new entry" && dev_bootstrap_path_prepend "/new entry" &&
    [[ $PATH == "/new entry::${HOME}/bin:other:other:" ]]
'
no_partial_load() {
  zsh -fc 'if source "$HOME/.zshrc"; then exit 1; fi; [[ -z ${ORDER-} ]]'
}
for bad in ../extra missing b '' 'a.zsh' '$(uname)'; do
  printf 'b\n%s\n' "$bad" > "$list"
  no_partial_load
done
printf 'b\na\0/extra\n' > "$list"
no_partial_load
cp "$tmp/list" "$list"
mv "$dir/env.d/a.zsh" "$tmp/a"
ln -s "$tmp/a" "$dir/env.d/a.zsh"
no_partial_load
rm "$dir/env.d/a.zsh"
mv "$tmp/a" "$dir/env.d/a.zsh"
touch "$dir/env.d/a.zsh.zwc"
no_partial_load
# An empty selection loads nothing, even with old fragment files in env.d.
: > "$list"
zsh -fc 'source "$HOME/.zshrc" && [[ -z ${ORDER-} && -z ${UNEXPECTED-} ]]'
echo "PASS: $(zsh --version), staged migration, retry, ordered loading and PATH"
