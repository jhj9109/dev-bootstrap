#!/usr/bin/env bash
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
project="$tmp/project"
export HOME="$tmp/home space" TRACE="$tmp/calls"
mkdir -p "$project" "$HOME/.config/dev-bootstrap/env.d" "$HOME/.ssh" "$tmp/bin"
cp -R "$root"/{setup.sh,bootstrap.sh,lib,core,modules,config} "$project/"
envfile="$project/config/environments/minimal.conf"
# Seed a managed loader and an active fragment to exercise the old all fallback.
cp "$root/modules/shell/loader.zsh" "$HOME/.config/dev-bootstrap/env.zsh"
echo node > "$HOME/.config/dev-bootstrap/env.d/active.list"
echo 'user setting' > "$HOME/.zshrc"
chmod 700 "$HOME/.ssh"
ln -s .zshrc "$HOME/user-link"
: > "$TRACE"
for cmd in curl ssh ssh-keygen gh git make ditto zsh; do
  cat > "$tmp/bin/$cmd" <<'SPY'
#!/bin/sh
echo "${0##*/}" >> "$TRACE"
exit 23
SPY
  chmod +x "$tmp/bin/$cmd"
done
export PATH="$tmp/bin:$PATH"

fixture() {
  local id=$1 deps=${2-}
  mkdir -p "$project/modules/$id"
  {
    printf '%s_hook() { echo "%s hook" >> "$TRACE"; return 23; }\n' "$id" "$id"
    printf 'register_module --id %s --name Fixture --platforms Linux --check %s_hook --apply %s_hook --verify %s_hook' \
      "$id" "$id" "$id" "$id"
    if [[ -n $deps ]]; then printf ' --depends "%s"' "$deps"; fi
    printf '\n'
  } > "$project/modules/$id/module.sh"
}
fixture first
fixture second
fixture both 'first second'
# Intercept dispatch after discovery, leaving registration and config hooks intact.
awk '/^main "\$@"$/ { print ". \"$ROOT_DIR/spies.sh\"" } { print }' "$root/setup.sh" > "$project/setup.sh"
cat > "$project/spies.sh" <<'SPIES'
planner_forbidden_hook() { echo "execution hook" >> "$TRACE"; return 23; }
shell_configure() { echo "Shell adapter" >> "$TRACE"; return 23; }
for i in "${!REGISTRY_IDS[@]}"; do
  REGISTRY_CHECK[i]=planner_forbidden_hook
  REGISTRY_APPLY[i]=planner_forbidden_hook
  REGISTRY_VERIFY[i]=planner_forbidden_hook
done
SPIES

snapshot() { tar -cf "$1" -C "$HOME" .; }
snapshot "$tmp/before"
unchanged() {
  snapshot "$tmp/after"
  cmp "$tmp/before" "$tmp/after"
  [[ ! -s $TRACE ]] || { cat "$TRACE" >&2; return 1; }
}
select_modules() { printf 'ENABLED_MODULES=(%s)\n' "$*" > "$envfile"; }
run() { "$project/$1" --environment minimal "${@:2}"; }

check_pair() {
  local expected=$1 rc=0
  run setup.sh plan --profile secondary --method ssh --no-passphrase > "$tmp/plan" 2>&1 || rc=$?
  [[ $rc == "$expected" ]] || { cat "$tmp/plan" >&2; return 1; }
  unchanged
  rc=0
  run bootstrap.sh all --profile secondary --dry-run --method ssh --no-passphrase > "$tmp/dry" 2>&1 || rc=$?
  [[ $rc == "$expected" ]] && cmp "$tmp/plan" "$tmp/dry" || return 1
  unchanged
}
reject() {
  check_pair 2
  grep -Fq -- "$1" "$tmp/plan"
  # Every full-plan execution entry rejects before manifest preflight or hooks.
  local action rc
  for action in all check apply; do
    rc=0
    run setup.sh "$action" > "$tmp/all" 2>&1 || rc=$?
    [[ $rc == 2 ]]
    unchanged
  done
}
select_modules second first both
check_pair 0
grep -Fxq 'Environment: minimal' "$tmp/plan"
grep -Fxq 'Account: secondary' "$tmp/plan"
grep -Fxq 'Target OS: macos' "$tmp/plan"
grep -Fxq 'Auth method: ssh' "$tmp/plan"
grep -Fxq 'Allow unencrypted SSH key: true' "$tmp/plan"
grep -Fxq 'Modules: 3' "$tmp/plan"
grep -Fxq '1. second | depends: none | platforms: Linux' "$tmp/plan"
grep -Fxq '2. first | depends: none | platforms: Linux' "$tmp/plan"
grep -Fxq '3. both | depends: first second | platforms: Linux' "$tmp/plan"
select_modules first both; reject 'both requires missing module second'
select_modules first both second; reject 'second must precede both'
select_modules first first; reject 'Duplicate module'
select_modules unknown; reject 'Unknown module'
fixture first first
select_modules first; reject 'first depends on itself'
fixture first second
fixture second both
fixture both first
select_modules both second first; reject 'Dependency cycle'

select_modules workspace repository
check_pair 0
grep -Fq '2. repository | depends: workspace' "$tmp/plan"
select_modules repository; reject 'repository requires missing module workspace'
select_modules node; reject 'node requires missing module shell'
select_modules python; reject 'python requires missing module shell'
printf '%s\n' 'PYTHON_INSTALL_METHOD=source' 'PYTHON_VERSION=3.12.7' >> "$envfile"
check_pair 0
grep -Fq '1. python | depends: none' "$tmp/plan"
select_modules shell python node
check_pair 0
grep -Fq '2. python | depends: shell' "$tmp/plan"
select_modules
check_pair 0
grep -Fxq 'Modules: 0' "$tmp/plan"
run setup.sh all > "$tmp/all"
unchanged
echo 'PASS: plan and dry-run validate ordered dependencies, preserve HOME and call no execution hooks or tools'
