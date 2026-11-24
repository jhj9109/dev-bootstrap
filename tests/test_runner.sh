#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/modules/sample" "$tmp/start" "$tmp/other"
source "$root/lib/logger.sh"
source "$root/core/registry.sh"
source "$root/core/runner.sh"

cat > "$tmp/modules/sample/module.sh" <<'MODULE'
sample_record() {
  printf '%s\n' "$1" >> "$TRACE"
  [[ $SAMPLE_SETTING == configured && $PWD == "$START_DIR" ]] || return 98
  SAMPLE_SETTING=changed
  cd "$OTHER_DIR" || return 99
  return "$2"
}
sample_check()  { [[ $# == 0 ]] && sample_record check  "$CHECK_CODE"; }
sample_apply()  { [[ $# == 0 ]] && sample_record apply  "$APPLY_CODE"; }
sample_verify() { [[ $# == 0 ]] && sample_record verify "$VERIFY_CODE"; }
register_module --id sample --name Sample --platforms Darwin \
  --check sample_check --apply sample_apply --verify sample_verify
MODULE
discover_modules "$tmp"
TRACE="$tmp/trace" OTHER_DIR="$tmp/other" START_DIR="$tmp/start"
SAMPLE_SETTING=configured
cd "$START_DIR"
uname() { [[ $1 == -s ]] && printf '%s\n' "$platform_fixture"; }

expect_run() {
  local id=$1 expected_rc=$2 expected_state=$3 expected_phase=$4 expected_code=$5 expected_calls=$6
  local rc=0 calls
  : > "$TRACE"
  runner_run "$id" > "$tmp/out" 2>&1 || rc=$?
  calls=$(paste -sd, "$TRACE")
  if [[ $rc != "$expected_rc" || $RUNNER_STATUS != "$expected_state" ||
        $RUNNER_PHASE != "$expected_phase" || $RUNNER_HOOK_STATUS != "$expected_code" ||
        $calls != "$expected_calls" ]]; then
    cat "$tmp/out" >&2
    printf 'Expected %s/%s/%s/%s [%s], got %s/%s/%s/%s [%s]\n' \
      "$expected_rc" "$expected_state" "$expected_phase" "$expected_code" "$expected_calls" \
      "$rc" "$RUNNER_STATUS" "$RUNNER_PHASE" "$RUNNER_HOOK_STATUS" "$calls" >&2
    return 1
  fi
  [[ $SAMPLE_SETTING == configured && $PWD == "$START_DIR" ]]
}

platform_fixture=Darwin
while read -r CHECK_CODE APPLY_CODE VERIFY_CODE rc state phase code calls; do
  expect_run sample "$rc" "$state" "$phase" "$code" "$calls"
done <<'CASES'
0  0  0  0 SKIPPED      check  0  check
3  0  0  1 BLOCKED      check  3  check
4  0  0  1 NEEDS_ACTION check  4  check
23 0  0  1 FAILED       check  23 check
10 3  0  1 BLOCKED      apply  3  check,apply
10 4  0  1 NEEDS_ACTION apply  4  check,apply
10 10 0  1 FAILED       apply  10 check,apply
10 23 0  1 FAILED       apply  23 check,apply
10 0  3  1 BLOCKED      verify 3  check,apply,verify
10 0  4  1 NEEDS_ACTION verify 4  check,apply,verify
10 0  10 1 FAILED       verify 10 check,apply,verify
10 0  23 1 FAILED       verify 23 check,apply,verify
10 0  0  0 SUCCESS      verify 0  check,apply,verify
CASES
platform_fixture=Linux
expect_run sample 1 UNSUPPORTED platform '' ''
expect_run missing 1 FAILED registry '' ''
echo 'PASS: Runner states, original hook codes, call order and shell isolation'
