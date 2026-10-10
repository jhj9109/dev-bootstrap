#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HOME="$TMP" "$ROOT/setup.sh" help | grep -q 'Phase 4'
set +e
HOME="$TMP" "$ROOT/setup.sh" bogus >"$TMP/out" 2>&1
status=$?
set -e
[[ "$status" == 2 ]]
printf '0\n' | HOME="$TMP" "$ROOT/setup.sh" | grep -q 'Select:'
# doctor should not create files or directories under HOME
HOME="$TMP" "$ROOT/setup.sh" doctor >"$TMP/doctor" 2>&1 || true
[[ "$(find "$TMP" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" == 2 ]]
echo 'PASS: CLI, invalid args, interactive exit, non-destructive doctor'
