#!/usr/bin/env bash
set -eu
set -o pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
project="$tmp/project"
export HOME="$tmp/home space"
mkdir "$HOME" "$project" "$tmp/before"
# Exercise the current checkout, including pending code changes, without loading
# a developer's private profiles, accounts or repository manifest.
cp -R "$root"/{setup.sh,bootstrap.sh,core,lib} "$tmp/before/"
cp -R "$tmp/before/." "$project/"
cp -R "$root/modules" "$project/"
mkdir "$project/config"
cp -R "$root/config"/{defaults.conf,environments} "$project/config/"

common_unchanged() {
  local path
  for path in setup.sh bootstrap.sh core lib; do
    diff -r "$tmp/before/$path" "$project/$path"
  done
}
common_unchanged

mkdir "$project/modules/sample" "$project/modules/sample_cache"
cat > "$project/modules/sample/module.sh" <<'MODULE'
sample_defaults() { SAMPLE_VERSION=1; }
sample_validate() { [[ $SAMPLE_VERSION =~ ^[0-9]+$ ]]; }

sample_check() {
  local path="$HOME/.dev-bootstrap-sample"
  echo "sample hook: inspect version" >&2
  [[ ! -L $path ]] || return 1
  [[ -e $path ]] || return 10
  [[ -f $path && -r $path ]] || return 1
  local rc=0
  cmp -s "$path" - <<< "$SAMPLE_VERSION" || rc=$?
  case $rc in 0) return 0 ;; 1) return 10 ;; *) return 1 ;; esac
}

sample_apply() (
  local tmp
  echo "sample hook: publish version" >&2
  umask 077
  tmp=$(mktemp "$HOME/.dev-bootstrap-sample.XXXXXXXX") || return 1
  trap 'rm -f "$tmp"' EXIT
  printf '%s\n' "$SAMPLE_VERSION" > "$tmp" || return 1
  mv "$tmp" "$HOME/.dev-bootstrap-sample"
)

register_module --id sample --name 'Sample tool' --platforms 'Darwin Linux' \
  --keys SAMPLE_VERSION --defaults sample_defaults --validate sample_validate \
  --check sample_check --apply sample_apply --verify sample_check
MODULE
cat > "$project/modules/sample_cache/module.sh" <<'MODULE'
sample_cache_check() {
  echo "sample_cache hook: inspect directory" >&2
  [[ ! -L "$HOME/sample-cache" ]] || return 1
  [[ -e "$HOME/sample-cache" ]] || return 10
  [[ -d "$HOME/sample-cache" ]]
}
sample_cache_apply() {
  echo "sample_cache hook: create directory" >&2
  mkdir "$HOME/sample-cache"
}
register_module --id sample_cache --name 'Sample cache' --platforms 'Darwin Linux' \
  --depends sample --check sample_cache_check --apply sample_cache_apply --verify sample_cache_check
MODULE

cli="$project/bootstrap.sh"
config="$project/config/environments/minimal.conf"
state="$HOME/.dev-bootstrap-sample"
environment() {
  printf '%s\n' 'ENABLED_MODULES=(sample sample_cache workspace)' > "$config"
  if (( $# )); then printf 'SAMPLE_VERSION=%s\n' "$1" >> "$config"; fi
}
run() {
  local expected=$1 rc=0
  shift
  "$cli" --environment minimal "$@" > "$tmp/out" 2>&1 || rc=$?
  [[ $rc == "$expected" ]] || { cat "$tmp/out" >&2; echo "Expected $expected from $*, got $rc" >&2; return 1; }
}
has() { grep -Fqx -- "$1" "$tmp/out" || { cat "$tmp/out" >&2; echo "Missing: $1" >&2; return 1; }; }
# Match hook diagnostics even when a menu prompt precedes the first message.
hooks() {
  local actual
  actual=$(sed -En 's/^.*(sample(_cache)? hook: .*)$/\1/p' "$tmp/out")
  [[ $actual == "$1" ]] || { cat "$tmp/out" >&2; echo "Expected hooks: $1" >&2; return 1; }
}
inspect='sample hook: inspect version'
publish='sample hook: publish version'
snapshot() { tar -cf "$1" -C "$HOME" .; }
home_unchanged() { snapshot "$tmp/after.tar"; cmp "$tmp/before.tar" "$tmp/after.tar"; }
version_is() { cmp "$state" - <<< "$1"; }

environment
common_unchanged
snapshot "$tmp/before.tar"
run 0 list
has 'sample  Sample tool'
hooks ''
run 0 help
has 'sample  Sample tool'
hooks ''
run 0 <<< 0
hooks ''
slot=$(sed -n 's/^\([0-9][0-9]*\)\. Apply sample (Sample tool)$/\1/p' "$tmp/out")
[[ $slot =~ ^[0-9]+$ ]]
run 0 plan
hooks ''
has 'Environment: minimal'
has 'Modules: 3'
has '1. sample | depends: none | platforms: Darwin Linux'
has '2. sample_cache | depends: sample | platforms: Darwin Linux'
has '3. workspace | depends: none | platforms: Darwin Linux'
cp "$tmp/out" "$tmp/plan"
run 0 all --dry-run
cmp "$tmp/plan" "$tmp/out"
run 1 check sample
hooks "$inspect"
has 'sample: CHANGE_NEEDED | check | goal needs changes'
run 1 apply sample_cache
hooks "$inspect"
has 'sample_cache: BLOCKED | dependency | requires sample (CHANGE_NEEDED)'
home_unchanged

run 0 apply sample
hooks "$inspect
$publish
$inspect"
has 'sample: SUCCESS | verify | goal satisfied'
version_is 1
ln "$state" "$tmp/original"
snapshot "$tmp/before.tar"
run 0 apply sample
hooks "$inspect"
has 'sample: SKIPPED | check | goal satisfied'
[[ "$state" -ef "$tmp/original" ]]
home_unchanged

environment 2
run 1 check sample
hooks "$inspect"
has 'sample: CHANGE_NEEDED | check | goal needs changes'
home_unchanged
# Select the item discovered from this menu, including its normal config reload.
run 0 <<< "$slot
0"
has 'sample: SUCCESS | verify | goal satisfied'
version_is 2
run 0 check sample
has 'sample: SKIPPED | check | goal satisfied'

snapshot "$tmp/before.tar"
environment invalid
run 2 all
hooks ''
grep -Fq 'sample: validation failed' "$tmp/out"
home_unchanged
environment 3
run 2 apply sample --version 3
hooks ''
home_unchanged
# The loader only accepts two environment names, even with a valid file present.
cp "$config" "$project/config/environments/extension.conf"
rc=0
"$cli" --environment extension plan > "$tmp/out" 2>&1 || rc=$?
[[ $rc == 2 ]]
grep -Fq 'Invalid environment' "$tmp/out"
home_unchanged

# Fail the actual publisher, then simulate a publisher that loses its write.
# Only the sample's single-target apply runs with these external commands.
tar -cf "$tmp/published.tar" -C "$HOME" .dev-bootstrap-sample
publication_unchanged() {
  [[ $(ls -A "$HOME") == .dev-bootstrap-sample ]]
  tar -cf "$tmp/actual.tar" -C "$HOME" .dev-bootstrap-sample
  cmp "$tmp/published.tar" "$tmp/actual.tar"
}
mkdir "$tmp/bin"
printf '#!/bin/sh\nexit 23\n' > "$tmp/bin/mv"
chmod +x "$tmp/bin/mv"
PATH="$tmp/bin:$PATH" run 1 apply sample
has 'sample: FAILED | apply | apply failed (hook exit 23)'
publication_unchanged
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/mv"
PATH="$tmp/bin:$PATH" run 1 apply sample
has 'sample: FAILED | verify | verify failed (hook exit 10)'
publication_unchanged

# A real conflict in check must preserve the link and its target. The later
# independent workspace must still be created while the dependent stays absent.
mv "$state" "$tmp/previous"
ln -s "$tmp/previous" "$state"
run 1 all
hooks "$inspect"
has 'sample: FAILED | check | check failed (hook exit 1)'
has 'sample_cache: BLOCKED | dependency | requires sample (FAILED)'
has 'workspace: SUCCESS | verify | goal satisfied'
has 'Summary: 3 module(s), 2 incomplete'
[[ -L $state && ! -e "$HOME/sample-cache" && -d "$HOME/Documents" ]]
version_is 2
rm "$state"
run 0 all
has 'sample: SUCCESS | verify | goal satisfied'
has 'sample_cache: SUCCESS | verify | goal satisfied'
has 'workspace: SKIPPED | check | goal satisfied'
version_is 3
[[ -d "$HOME/sample-cache" ]]
snapshot "$tmp/before.tar"
run 0 all
for id in sample sample_cache workspace; do has "$id: SKIPPED | check | goal satisfied"; done
home_unchanged
common_unchanged
echo 'PASS: module extension, dependency recovery and byte-identical entry points, core and lib'
