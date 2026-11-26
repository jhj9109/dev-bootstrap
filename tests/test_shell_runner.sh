#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME/.nvm" "$tmp/project" "$tmp/bin" "$tmp/outside"
cp -R "$root"/{setup.sh,bootstrap.sh,core,lib,modules,config} "$tmp/project/"
project="$tmp/project"
export PATH="$tmp/bin:$PATH"
rc="$HOME/.zshrc"
dir="$HOME/.config/dev-bootstrap"
managed="$dir/env.zsh"
marker='# Dev Bootstrap managed environment'
loader='[ -f "$HOME/.config/dev-bootstrap/env.zsh" ] && . "$HOME/.config/dev-bootstrap/env.zsh"'
expect_shell() {
  local expected=$1 message=$2 status=0
  "$project/bootstrap.sh" configure shell > "$tmp/out" 2>&1 || status=$?
  if [[ $status != "$expected" ]] || ! grep -Fq "$message" "$tmp/out"; then
    cat "$tmp/out" >&2
    echo "Expected exit $expected and $message, got $status" >&2
    return 1
  fi
}
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
no_temps() {
  [[ -z $(find "$HOME" \( -name '.zshrc.*' -o -name '.env.*' \) -print) ]]
}

printf 'touch "$HOME/ran-nvm"\n' > "$HOME/.nvm/nvm.sh"
printf 'touch "$HOME/ran-rc"' > "$rc"
chmod 640 "$rc"
expect_shell 0 'shell: SUCCESS'
[[ $(mode "$rc") == 640 && $(mode "$managed") == 600 ]]
printf 'touch "$HOME/ran-rc"\n%s\n%s\n' "$marker" "$loader" > "$tmp/expected"
cmp "$tmp/expected" "$rc"
cmp "$project/modules/shell/loader.zsh" "$managed"
# Detect replacement or in-place writes on a no-op run.
touch -t 200001010101 "$rc" "$managed" "$tmp/expected"
ln "$rc" "$tmp/rc-inode"
ln "$managed" "$tmp/env-inode"
expect_shell 0 'shell: SKIPPED'
[[ $rc -ef $tmp/rc-inode && $managed -ef $tmp/env-inode ]]
[[ ! $rc -nt $tmp/expected && ! $managed -nt $tmp/expected ]]
rm "$managed"
expect_shell 0 'shell: SUCCESS'
[[ $rc -ef $tmp/rc-inode && ! $rc -nt $tmp/expected ]]
rm "$rc"
expect_shell 0 'shell: SUCCESS'
[[ $(mode "$rc") == 600 ]]
printf '%s' "$marker" > "$rc"
expect_shell 0 'shell: SUCCESS'
[[ $(cat "$rc") == "$marker"$'\n'"$loader" ]]
printf '8\n0\n' | "$project/setup.sh" > "$tmp/menu"
grep -Fq 'shell: SKIPPED' "$tmp/menu"

# All conflicts are detected before recreating the other file.
rm "$managed"
for lines in "$marker"$'\n# user edit' "$marker"$'\n'"$loader"$'\n'"$loader" "$loader"; do
  printf '%s\n' "$lines" > "$rc"
  cp "$rc" "$tmp/before"
  expect_shell 1 'shell: NEEDS_ACTION'
  cmp "$rc" "$tmp/before"
  [[ ! -e $managed ]]
done
rm "$rc"
printf 'touch "$HOME/ran-edited"\n' > "$managed"
cp "$managed" "$tmp/before"
expect_shell 1 'shell: NEEDS_ACTION'
cmp "$managed" "$tmp/before"
[[ ! -e $rc ]]
rm "$managed"
for path in "$managed" "$rc" "$dir" "$HOME/.config"; do
  if [[ -d $path ]]; then mv "$path" "$tmp/parent"; fi
  ln -s "$tmp/outside" "$path"
  expect_shell 1 'check returned 1'
  [[ -L $path && -z $(ls -A "$tmp/outside") ]]
  rm "$path"
  if [[ -d $tmp/parent ]]; then mv "$tmp/parent" "$path"; fi
done

echo 'user setting' > "$rc"
cp "$rc" "$tmp/before"
chmod 000 "$rc"
if [[ ! -r $rc ]]; then
  expect_shell 1 'check returned 1'
  [[ ! -e $managed && $(mode "$rc") =~ ^0+$ ]]
fi
chmod 400 "$rc"
if [[ ! -w $rc ]]; then
  expect_shell 1 'apply returned 1'
  [[ ! -e $managed && $(mode "$rc") == 400 ]]
  no_temps
fi
chmod 600 "$rc"
cat > "$tmp/bin/awk" <<'MOCK'
#!/usr/bin/env bash
exit 2
MOCK
chmod +x "$tmp/bin/awk"
expect_shell 1 'check returned 1'
[[ ! -e $managed ]]
cmp "$tmp/before" "$rc"
rm "$tmp/bin/awk"

# A template read/copy failure after creating a staging file is retryable.
REAL_CAT=$(command -v cat)
export REAL_CAT
cat > "$tmp/bin/cat" <<'MOCK'
#!/usr/bin/env bash
case "${1:-}" in */modules/shell/loader.zsh) printf 'partial'; exit 1 ;; esac
exec "$REAL_CAT" "$@"
MOCK
chmod +x "$tmp/bin/cat"
expect_shell 1 'apply returned 1'
[[ ! -e $managed ]]
cmp "$tmp/before" "$rc"
no_temps
rm "$tmp/bin/cat"

# Fail the final rename after env.zsh is committed. Retry uses that file.
printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/mv"
chmod +x "$tmp/bin/mv"
expect_shell 1 'apply returned 1'
cmp "$tmp/before" "$rc"
cmp "$project/modules/shell/loader.zsh" "$managed"
no_temps
rm "$tmp/bin/mv"
expect_shell 0 'shell: SUCCESS'
expect_shell 0 'shell: SKIPPED'

# Simulate an apply reporting success without publishing the new rc.
rm "$rc"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/ln"
chmod +x "$tmp/bin/ln"
expect_shell 1 'verify returned 10'
no_temps
rm "$tmp/bin/ln"
expect_shell 0 'shell: SUCCESS'
[[ ! -e $HOME/ran-rc && ! -e $HOME/ran-edited && ! -e $HOME/ran-nvm ]]
echo 'PASS: shell loader, content and modes, skip, conflicts, symlinks, failure and retry'
