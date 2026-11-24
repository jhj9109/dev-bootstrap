#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
project="$tmp/project"
mkdir -p "$HOME" "$project" "$tmp/bin" "$tmp/outside"
cp -R "$root"/{setup.sh,bootstrap.sh,core,lib,modules,config} "$project/"

export MKDIR_TRACE="$tmp/mkdir-calls"
: > "$MKDIR_TRACE"
cat > "$tmp/bin/mkdir" <<'MOCK'
#!/usr/bin/env bash
echo mkdir >> "$MKDIR_TRACE"
case "${MKDIR_MODE:-create}" in
  fail) exit 1 ;;
  noop) exit 0 ;;
  create) exec /bin/mkdir "$@" ;;
esac
MOCK
chmod +x "$tmp/bin/mkdir"
export PATH="$tmp/bin:$PATH"
set_workspace() {
  printf 'WORKSPACE_DIR=%q\n' "$1" > "$project/config/profiles.conf"
}
expect_cli() {
  local expected_rc=$1 expected_log=$2 rc=0
  "$project/bootstrap.sh" configure workspace > "$tmp/out" 2>&1 || rc=$?
  if [[ $rc != "$expected_rc" ]] || ! grep -Fq "$expected_log" "$tmp/out"; then
    cat "$tmp/out" >&2
    printf 'Expected exit %s and "%s", got exit %s\n' "$expected_rc" "$expected_log" "$rc" >&2
    return 1
  fi
}

workspace="$HOME/Work Area"
set_workspace "$workspace"
expect_cli 0 'workspace: SUCCESS'
[[ -d $workspace ]]
echo keep > "$workspace/notes"
expect_cli 0 'workspace: SKIPPED'
[[ $(cat "$workspace/notes") == keep && $(cat "$MKDIR_TRACE") == mkdir ]]

set_workspace "$HOME/Menu"
printf '9\n9\n0\n' | "$project/setup.sh" > "$tmp/menu"
grep -Fq 'workspace: SUCCESS' "$tmp/menu"
grep -Fq 'workspace: SKIPPED' "$tmp/menu"
[[ -d "$HOME/Menu" && $(wc -l < "$MKDIR_TRACE") -eq 2 ]]

: > "$MKDIR_TRACE"
echo original > "$tmp/outside/keep"
ln -s "$tmp/outside" "$HOME/parent"
for path in "$workspace/notes" "$HOME/parent" "$HOME/parent/new" "$tmp/outside/new" "$HOME/../outside/new"; do
  set_workspace "$path"
  expect_cli 2 'workspace: FAILED (check returned 2)'
done
[[ ! -s $MKDIR_TRACE && $(cat "$workspace/notes") == keep ]]
[[ -L "$HOME/parent" && $(readlink "$HOME/parent") == "$tmp/outside" ]]
[[ $(cat "$tmp/outside/keep") == original && ! -e "$tmp/outside/new" ]]

set_workspace "$HOME/New"
MKDIR_MODE=fail expect_cli 1 'workspace: FAILED (apply returned 1)'
MKDIR_MODE=noop expect_cli 5 'workspace: FAILED (apply returned 5)'
[[ ! -e "$HOME/New" ]]

# Inject a stricter postcondition into the temporary registration. The real
# apply must succeed before a verify failure can reach the CLI adapter.
entry="$project/modules/workspace/module.sh"
sed 's/--verify workspace_status/--verify workspace_fixture_verify/' "$entry" > "$tmp/entry"
{
  echo 'workspace_fixture_verify() { [[ -d "$WORKSPACE_DIR" ]] || return 99; return 10; }'
  cat "$tmp/entry"
} > "$entry"
expect_cli 5 'workspace: FAILED (verify returned 10)'
[[ -d "$HOME/New" && $(wc -l < "$MKDIR_TRACE") -eq 3 ]]
echo 'PASS: Workspace CLI/menu, legacy exit codes, file and parent symlink preservation'
