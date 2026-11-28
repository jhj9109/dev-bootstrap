#!/usr/bin/env bash
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bash "$root/tests/copy-project.sh" "$root" "$tmp"
cli="$tmp/bootstrap.sh"
export HOME="$tmp/home space"
dir="$HOME/.config/dev-bootstrap"
list="$dir/env.d/active.list"
mkdir -p "$dir" "$HOME/.nvm" "$HOME/.local/bin" "$tmp/bin"
printf 'ENABLED_MODULES=(shell node python)\n' > "$tmp/config/environments/classroom.conf"
printf 'ENABLED_MODULES=(shell)\n' > "$tmp/config/environments/minimal.conf"
cat > "$HOME/.nvm/nvm.sh" <<'NVM'
nvm() {
  case $1 in version) echo v24.8.0 ;; current) echo active ;; *) return 1 ;; esac
}
export NVM_BIN="$NVM_DIR/mock-bin"
case ":$PATH:" in *":$NVM_BIN:"*) ;; *) export PATH="$NVM_BIN:$PATH" ;; esac
NVM
mkdir "$HOME/.nvm/mock-bin"
printf '#!/bin/sh\necho fixture-node\n' > "$HOME/.nvm/mock-bin/node"
chmod +x "$HOME/.nvm/mock-bin/node"
printf '#!/bin/sh\necho 3.12.7\n' > "$HOME/.local/bin/uv"
chmod +x "$HOME/.local/bin/uv"
printf '# user config\n# Dev Bootstrap managed environment\n%s\n' \
  '[ -f "$HOME/.config/dev-bootstrap/env.zsh" ] && . "$HOME/.config/dev-bootstrap/env.zsh"' > "$HOME/.zshrc"
ln "$HOME/.zshrc" "$tmp/original-rc"
cp "$root/modules/shell/env.zsh" "$dir/env.zsh"
reject() { if "$@"; then echo 'Unexpected shell update success' >&2; exit 1; fi; }
# Fail each commit point separately, including a later live v2 list update.
cat > "$tmp/bin/mv" <<'MOCK'
#!/bin/sh
for arg do [ "$arg" != "$FAIL_TARGET" ] || exit 1; done
exec /bin/mv "$@"
MOCK
chmod +x "$tmp/bin/mv"
export PATH="$tmp/bin:$PATH" FAIL_TARGET="$dir/env.zsh"
reject "$cli" configure shell
cmp "$dir/env.zsh" "$root/modules/shell/env.zsh"
FAIL_TARGET=''
"$cli" all
[[ $(cat "$list") == $'node\npython' && $HOME/.zshrc -ef $tmp/original-rc ]]
both_loaded() {
  zsh -fc 'source "$HOME/.zshrc" && source "$HOME/.zshrc" &&
    [[ $(nvm current) == active && $(node) == fixture-node && $(uv) == 3.12.7 && $NVM_BIN == "$HOME/.nvm/mock-bin" ]] &&
    [[ ${#${(M)path:#"$HOME/.local/bin"}} == 1 ]]'
}
both_loaded
mv "$HOME/.nvm/nvm.sh" "$tmp/nvm.sh"
ln -s "$tmp/nvm.sh" "$HOME/.nvm/nvm.sh"
reject zsh -fc 'source "$HOME/.zshrc"'
rm "$HOME/.nvm/nvm.sh"
mv "$tmp/nvm.sh" "$HOME/.nvm/nvm.sh"
FAIL_TARGET="$list"
reject "$cli" --environment minimal all
both_loaded
FAIL_TARGET=''
"$cli" --environment minimal all
[[ ! -s $list && -f $dir/env.d/node.zsh && -f $dir/env.d/python.zsh ]]
zsh -fc 'source "$HOME/.zshrc" && (( ! $+functions[nvm] )) && [[ $path[(Ie)$HOME/.local/bin] == 0 ]]'
"$cli" install python
[[ $(cat "$list") == python ]]
"$cli" install node
[[ $(cat "$list") == $'python\nnode' ]]
both_loaded
# Refresh an old, unedited template only when its own module is requested.
printf '\n# template revision\n' >> "$tmp/modules/python/python.zsh"
"$cli" install node
cmp "$dir/env.d/python.zsh" "$root/modules/python/python.zsh"
FAIL_TARGET="$dir/env.d/python.zsh"
reject "$cli" install python
cmp "$dir/env.d/python.zsh" "$root/modules/python/python.zsh"
FAIL_TARGET=''
"$cli" install python
cmp "$dir/env.d/python.zsh" "$tmp/modules/python/python.zsh"
rm "$dir/env.d/node.zsh"
"$cli" install node
cmp "$dir/env.d/node.zsh" "$root/modules/node/node.zsh"
echo '# user edit' >> "$dir/env.d/python.zsh"
reject "$cli" install python
grep -q 'user edit' "$dir/env.d/python.zsh"
"$cli" --environment minimal all
grep -q 'user edit' "$dir/env.d/python.zsh"
mv "$dir/env.d/python.zsh" "$tmp/user-file"
ln -s "$tmp/user-file" "$dir/env.d/python.zsh"
reject "$cli" install python
[[ ! -s $list && -L $dir/env.d/python.zsh ]]
# Source strategy in a full configuration never activates the uv PATH fragment.
echo 'PYTHON_INSTALL_METHOD=source' >> "$tmp/config/defaults.conf"
"$cli" configure shell
[[ $(cat "$list") == node ]]
zsh -fc 'source "$HOME/.zshrc" && [[ $(nvm current) == active && $path[(Ie)$HOME/.local/bin] == 0 ]]'
printf 'custom\n' > "$list"
reject "$cli" configure shell
[[ $(cat "$list") == custom ]]
printf '../invalid\n' > "$list"
reject "$cli" configure shell
[[ $(cat "$list") == ../invalid ]]
echo "PASS: $(zsh --version), v1 migration, v2 repair, scoped activation and retry"
