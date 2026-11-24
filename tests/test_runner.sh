#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
project="$tmp/project"
mkdir "$HOME" "$project" "$tmp/other"
cp -R "$root"/{setup.sh,bootstrap.sh,core,lib,modules,config} "$project/"

mkdir "$project/modules/sample"
cat > "$project/modules/sample/module.sh" <<'FIXTURE'
sample_check() {
  [[ $# == 0 ]] || return 90
  sample_record check "$CHECK_CODE"
}
sample_apply() {
  [[ $# == 0 ]] || return 90
  sample_record apply "$APPLY_CODE"
}
sample_verify() {
  [[ $# == 0 ]] || return 90
  sample_record verify "$VERIFY_CODE"
}
sample_record() {
  [[ "$SAMPLE_SETTING" == original && "$PWD" == "$START_DIR" ]] || return 91
  printf '%s ' "$1" >> "$TRACE"
  SAMPLE_SETTING=changed
  cd "$OTHER_DIR" || return 92
  return "$2"
}
register_module --id sample --name Sample --platforms 'Darwin Linux' \
  --check sample_check --apply sample_apply --verify sample_verify
FIXTURE
source "$project/lib/logger.sh"
source "$project/modules/workspace.sh"
source "$project/core/registry.sh"
source "$project/core/runner.sh"
discover_modules "$project"

TRACE="$tmp/hooks"
START_DIR="$PWD" OTHER_DIR="$tmp/other" SAMPLE_SETTING=original
TEST_PLATFORM=Linux
uname() { [[ "$1" == -s ]] && printf '%s\n' "$TEST_PLATFORM"; }

expect_run() {
  local module="$1" expected_exit="$2" expected_status="$3" expected_phase="$4"
  local expected_code="$5" expected_trace="$6" status=0
  : > "$TRACE"
  runner_run "$module" >"$tmp/out" 2>&1 || status=$?
  if [[ "$status:$RUNNER_STATUS:$RUNNER_PHASE:$RUNNER_HOOK_STATUS" != "$expected_exit:$expected_status:$expected_phase:$expected_code" ||
        "$(cat "$TRACE")" != "$expected_trace" ]]; then
    cat "$tmp/out" >&2
    printf 'Expected %s %s:%s (exit %s), got %s %s:%s (exit %s)\n' \
      "$expected_status" "$expected_phase" "$expected_code" "$expected_exit" \
      "$RUNNER_STATUS" "$RUNNER_PHASE" "$RUNNER_HOOK_STATUS" "$status" >&2
    printf 'Expected hooks [%s], got [%s]\n' "$expected_trace" "$(cat "$TRACE")" >&2
    return 1
  fi
  [[ "$SAMPLE_SETTING" == original && "$PWD" == "$START_DIR" ]]
}

CHECK_CODE=10 APPLY_CODE=0 VERIFY_CODE=0
expect_run sample 0 SUCCESS verify 0 'check apply verify '
VERIFY_CODE=10
expect_run sample 1 FAILED verify 10 'check apply verify '
VERIFY_CODE=3
expect_run sample 1 BLOCKED verify 3 'check apply verify '
VERIFY_CODE=4
expect_run sample 1 NEEDS_ACTION verify 4 'check apply verify '
APPLY_CODE=10
expect_run sample 1 FAILED apply 10 'check apply '
APPLY_CODE=3
expect_run sample 1 BLOCKED apply 3 'check apply '
APPLY_CODE=4
expect_run sample 1 NEEDS_ACTION apply 4 'check apply '
CHECK_CODE=23
expect_run sample 1 FAILED check 23 'check '
CHECK_CODE=3
expect_run sample 1 BLOCKED check 3 'check '
CHECK_CODE=4
expect_run sample 1 NEEDS_ACTION check 4 'check '
CHECK_CODE=0
expect_run sample 0 SKIPPED check 0 'check '
TEST_PLATFORM=Other
expect_run sample 1 UNSUPPORTED platform '' ''
expect_run absent 1 FAILED registry '' ''

# Verify the shared CLI/menu path with the real Workspace hooks.
workspace="$HOME/Work Area/Documents"
printf 'WORKSPACE_DIR=%q\n' "$workspace" > "$project/config/profiles.conf"
"$project/bootstrap.sh" configure workspace > "$tmp/out"
grep -Fq 'workspace: SUCCESS' "$tmp/out"
[[ -d "$workspace" ]]
printf 'keep\n' > "$workspace/existing.txt"
printf '9\n0\n' | "$project/setup.sh" > "$tmp/out"
grep -Fq 'workspace: SKIPPED' "$tmp/out"
[[ "$(cat "$workspace/existing.txt")" == keep ]]

expect_workspace_error() {
  local expected="$1" status=0
  "$project/setup.sh" configure workspace >"$tmp/out" 2>&1 || status=$?
  if [[ "$status" != "$expected" ]]; then
    cat "$tmp/out" >&2
    printf 'Expected Workspace exit %s, got %s\n' "$expected" "$status" >&2
    return 1
  fi
}

# Stub mkdir to record every apply attempt and simulate both failure modes.
mkdir "$tmp/bin"
export WORKSPACE_MKDIR_TRACE="$tmp/mkdir-calls"
cat > "$tmp/bin/mkdir" <<'FIXTURE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$WORKSPACE_MKDIR_TRACE"
exit "${WORKSPACE_MKDIR_EXIT:-0}"
FIXTURE
chmod +x "$tmp/bin/mkdir"
export PATH="$tmp/bin:$PATH"

printf 'keep file\n' > "$HOME/file"
printf 'WORKSPACE_DIR=%q\n' "$HOME/file" > "$project/config/profiles.conf"
expect_workspace_error 2
grep -Fq 'workspace: FAILED (check exited 2)' "$tmp/out"
[[ "$(cat "$HOME/file")" == 'keep file' && ! -e "$WORKSPACE_MKDIR_TRACE" ]]

printf 'keep target\n' > "$tmp/other/original.txt"
ln -s "$tmp/other" "$HOME/linked"
printf 'WORKSPACE_DIR=%q\n' "$HOME/linked/new" > "$project/config/profiles.conf"
expect_workspace_error 2
[[ -L "$HOME/linked" && "$(readlink "$HOME/linked")" == "$tmp/other" ]]
[[ "$(cat "$tmp/other/original.txt")" == 'keep target' && ! -e "$tmp/other/new" && ! -e "$WORKSPACE_MKDIR_TRACE" ]]

printf 'WORKSPACE_DIR=%q\n' "$HOME/../outside" > "$project/config/profiles.conf"
expect_workspace_error 2
[[ ! -e "$tmp/outside" && ! -e "$WORKSPACE_MKDIR_TRACE" ]]

printf 'WORKSPACE_DIR=%q\n' "$HOME/missing" > "$project/config/profiles.conf"
export WORKSPACE_MKDIR_EXIT=27
expect_workspace_error 1
grep -Fq 'workspace: FAILED (apply exited 1)' "$tmp/out"
[[ "$(wc -l < "$WORKSPACE_MKDIR_TRACE")" -eq 1 ]]

unset WORKSPACE_MKDIR_EXIT
expect_workspace_error 5
grep -Fq 'workspace: FAILED (verify exited 10)' "$tmp/out"
[[ ! -e "$HOME/missing" && "$(wc -l < "$WORKSPACE_MKDIR_TRACE")" -eq 2 ]]
echo 'PASS: Runner states, hook codes and isolation, Workspace CLI/menu and path preservation'
