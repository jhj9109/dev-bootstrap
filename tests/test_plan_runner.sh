#!/usr/bin/env bash
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
project="$tmp/project"
export HOME="$tmp/home space" TRACE="$tmp/trace"
mkdir -p "$project" "$HOME"
bash "$root/tests/copy-project.sh" "$root" "$project"
config="$project/config/environments/minimal.conf"
cli="$project/bootstrap.sh"
fixture() {
  local id=$1 deps=${2-} entry="$project/modules/$1/module.sh"
  mkdir -p "${entry%/*}"
  cat > "$entry" <<HOOKS
${id}_check() { echo '$id check' >> "\$TRACE"; [[ \$FAULT != '$id check' ]] || return 23; [[ -f "\$HOME/$id" ]] || return 10; }
${id}_apply() { echo '$id apply' >> "\$TRACE"; [[ \$FAULT != '$id apply' ]] || return 4; touch "\$HOME/$id"; }
${id}_verify() { echo '$id verify' >> "\$TRACE"; [[ \$FAULT != '$id verify' ]] && [[ -f "\$HOME/$id" ]]; }
HOOKS
  printf 'register_module --id %s --name Fixture --platforms "Darwin Linux" --check %s_check --apply %s_apply --verify %s_verify' \
    "$id" "$id" "$id" "$id" >> "$entry"
  if [[ -n $deps ]]; then printf ' --depends "%s"' "$deps" >> "$entry"; fi
  printf '\n' >> "$entry"
}

run() {
  local expected=$1 rc=0
  shift
  : > "$TRACE"
  "$cli" --environment minimal "$@" > "$tmp/out" 2>&1 || rc=$?
  [[ $rc == "$expected" ]] || { cat "$tmp/out" >&2; echo "Expected exit $expected, got $rc" >&2; return 1; }
}
trace() { [[ $(cat "$TRACE") == "$1" ]] || { cat "$TRACE" >&2; return 1; }; }
has() { grep -Fq -- "$1" "$tmp/out" || { cat "$tmp/out" >&2; return 1; }; }
snapshot() { tar -cf "$1" -C "$HOME" .; }

fixture base
fixture left base
fixture right base
fixture leaf 'left right'
fixture free
echo 'ENABLED_MODULES=(base left right leaf free)' > "$config"
export FAULT='base check'
snapshot "$tmp/before"
run 1 check
trace $'base check\nfree check'
has 'base: FAILED | check | check failed (hook exit 23)'
has 'left: BLOCKED | dependency | requires base (FAILED)'
has 'leaf: BLOCKED | dependency | requires left (BLOCKED)'
has 'free: CHANGE_NEEDED | check'
snapshot "$tmp/after"; cmp "$tmp/before" "$tmp/after"

FAULT='base apply'
run 1 all --profile secondary --method gh
trace $'base check\nbase apply\nfree check\nfree apply\nfree verify'
has 'base: NEEDS_ACTION | apply'
has 'right: BLOCKED | dependency | requires base (NEEDS_ACTION)'
has 'free: SUCCESS | verify'
has 'Retry: ./setup.sh apply free --environment minimal --profile secondary --method gh'
FAULT=''
run 0 apply base
trace $'base check\nbase apply\nbase verify'
touch "$HOME/left"
snapshot "$tmp/before"
run 1 apply leaf
trace $'base check\nleft check\nright check'
has 'right: CHANGE_NEEDED'
has 'leaf: BLOCKED | dependency | requires right (CHANGE_NEEDED)'
snapshot "$tmp/after"; cmp "$tmp/before" "$tmp/after"

run 0 apply right
trace $'base check\nright check\nright apply\nright verify'
run 0 apply leaf
trace $'base check\nleft check\nright check\nleaf check\nleaf apply\nleaf verify'
run 0 apply
trace $'base check\nleft check\nright check\nleaf check\nfree check'
has 'Summary: 5 module(s), 0 incomplete'
run 0 check
has 'leaf: SKIPPED | check'
rm "$HOME/base"
FAULT='base verify'
run 1 all
has 'base: FAILED | verify'
has 'leaf: BLOCKED | dependency'
trace $'base check\nbase apply\nbase verify\nfree check'
FAULT=''
echo 'ENABLED_MODULES=()' > "$config"
for cmd in check apply all; do run 0 "$cmd"; has 'Summary: 0 module(s), 0 incomplete'; trace ''; done
# A single request can inspect a registered dependency outside the environment.
run 0 check leaf
trace $'base check\nleft check\nright check\nleaf check'
fixture base leaf
run 2 apply leaf
trace ''
has 'Dependency cycle'
run 2 apply absent
trace ''
for cmd in plan check apply all; do
  run 2 "$cmd" --method gh --no-passphrase; trace ''
  run 2 "$cmd" --version 3; trace ''
  run 2 "$cmd" --repo "$HOME"; trace ''
done
run 2 all --dry-run --method gh --no-passphrase; trace ''

# Check the real Python strategy and version override before any installation.
echo 'ENABLED_MODULES=(python)' > "$config"
run 2 all
run 1 apply python --method uv
has 'python: BLOCKED | dependency | requires shell'
[[ ! -e $HOME/.config && ! -e $HOME/.local ]]
run 1 check python --method source --version 3.12.7
has 'Summary: 1 module(s), 1 incomplete'
has 'python: CHANGE_NEEDED'
run 2 apply python --method source --version 3.12
[[ ! -e $HOME/.local ]]
# Both runtime modules recheck Shell inside their own hook. Inject drift after
# the Runner's successful Shell probe and catch any attempted legacy repair.
cat >> "$project/modules/shell/module.sh" <<'HOOKS'
shell_check() { [[ $module_id == shell ]] || return 10; }
shell_configure() { echo 'unexpected Shell repair' >> "$TRACE"; return 23; }
HOOKS
for runtime in node python; do
  run 1 apply "$runtime"
  has 'shell: SKIPPED | check'
  has "$runtime: BLOCKED | check"
  trace ''
done

# Local Git overrides must reach every hook without changing global identity.
cat > "$project/config/accounts.conf" <<'CONF'
GITHUB_SECONDARY_USER=second
GITHUB_SECONDARY_EMAIL=second@example.com
CONF
repo="$tmp/work tree"
git init -q "$repo"
run 1 check git --profile secondary --repo "$repo"
has 'git: CHANGE_NEEDED | check'
run 0 apply git --profile secondary --repo "$repo"
[[ $(git -C "$repo" config --local user.name) == second && ! -e $HOME/.gitconfig ]]
run 0 check git --profile secondary --repo "$repo"
has 'git: SKIPPED | check'
echo 'PASS: planned runner, read-only diamond probes, transitive blocking, independent progress, retries, empty plans and strategy overrides'
