#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
bash "$ROOT/tests/copy-project.sh" "$ROOT" "$TMP/project"
ROOT="$TMP/project"

expect_usage_error() {
  local status=0
  HOME="$test_home" "$entry" "$@" >"$TMP/output" 2>&1 || status=$?
  if [[ "$status" != 2 ]]; then
    printf 'Expected exit 2 from %s %s, got %s\n' "$entry" "$*" "$status" >&2
    return 1
  fi
}

for script in setup.sh bootstrap.sh; do
  entry="$ROOT/$script"
  test_home="$TMP/$script-home"
  mkdir "$test_home"
  for help_option in help --help -h; do
    HOME="$test_home" "$entry" "$help_option" >"$TMP/output"
    grep -q 'Dev Bootstrap v2' "$TMP/output"
  done
  expect_usage_error plan --repo somewhere
  expect_usage_error all --dry-run --dry-run
  expect_usage_error all --method --dry-run
  expect_usage_error configure github --dry-run
  expect_usage_error bogus
  expect_usage_error install node --version
  expect_usage_error configure git --unknown

  printf '0\n' | HOME="$test_home" "$entry" >"$TMP/output"
  grep -q 'Select:' "$TMP/output"
  HOME="$test_home" "$entry" </dev/null >"$TMP/output"
  grep -q 'Select:' "$TMP/output"

  # doctor should not create files or directories under HOME.
  HOME="$test_home" "$entry" doctor >"$TMP/output" 2>&1 || true
  [[ -z "$(find "$test_home" -mindepth 1 -print)" ]]
  printf 'PASS: %s CLI, invalid args, interactive exit, non-destructive doctor\n' "$script"
done
