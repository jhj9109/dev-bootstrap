#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home" "$TMP/project" "$TMP/system"
bash "$ROOT/tests/copy-project.sh" "$ROOT" "$TMP/project"
project="$TMP/project"
# Isolate the read-only system installation probe even on a Mac with iTerm2.
cat >> "$project/modules/iterm.sh" <<'FIXTURE'
iterm_system_installed() { [[ -d "$MOCK_SYSTEM/iTerm.app" || -d "$MOCK_SYSTEM/iTerm2.app" ]]; }
FIXTURE
export MOCK_SYSTEM="$TMP/system"
export HOME="$TMP/home" PATH="$TMP/bin:$PATH" GIT_CONFIG_NOSYSTEM=1
cat > "$TMP/bin/uname" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_OS:-Darwin}"
MOCK
cat > "$TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo curl >> "$HOME/downloads"
printf '%s\n' "$@" > "$HOME/curl-args"
if [[ "${MOCK_CURL_FAIL:-0}" == 1 ]]; then exit 28; fi
while (($#)); do
  if [[ "$1" == -o ]]; then printf 'mock archive' > "$2"; exit 0; fi
  shift
done
exit 2
MOCK
cat > "$TMP/bin/ditto" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == -x ]]; then
  [[ ${MOCK_DITTO:-} != extract-failure ]] || exit 1
  [[ ${MOCK_DITTO:-} != missing-bundle ]] || exit 0
  mkdir -p "$4/iTerm.app"
else
  mkdir -p "$2"
  [[ ${MOCK_DITTO:-} != partial ]] || { touch "$2/incomplete"; exit 1; }
fi
MOCK
chmod +x "$TMP/bin/"*
"$project/setup.sh" install iterm > "$TMP/output" 2>&1
grep -q 'downloading stable release' "$TMP/output"
grep -q 'download complete' "$TMP/output"
grep -q 'extracting archive' "$TMP/output"
grep -q 'copying application' "$TMP/output"
grep -q 'installed in ~/Applications' "$TMP/output"
grep -qx -- '--no-progress-meter' "$HOME/curl-args"
grep -Fq -- '--connect-timeout 15 --speed-limit 1024 --speed-time 30 --retry 2 --retry-delay 2' \
  <<< "$(paste -sd' ' "$HOME/curl-args")"
[[ -d "$HOME/Applications/iTerm.app" ]]
"$project/setup.sh" install iterm > "$TMP/again" 2>&1
grep -q 'already installed' "$TMP/again"
rm -rf "$HOME/Applications"
expect_error() {
  local expected_rc=$1 message=$2 rc=0
  "$project/bootstrap.sh" install iterm > "$TMP/failure" 2>&1 || rc=$?
  [[ $rc == "$expected_rc" ]] && grep -Fq "$message" "$TMP/failure" || {
    cat "$TMP/failure" >&2
    echo "Expected exit $expected_rc and $message, got $rc" >&2
    return 1
  }
}
[[ $(wc -l < "$HOME/downloads") -eq 1 ]]
MOCK_CURL_FAIL=1 expect_error 1 'download failed'
MOCK_DITTO=extract-failure expect_error 1 'extraction failed'
MOCK_DITTO=missing-bundle expect_error 5 'apply returned 5'
MOCK_DITTO=partial expect_error 1 'copy failed'
[[ -z $(ls -A "$HOME/Applications") ]]
"$project/setup.sh" install iterm > "$TMP/retry"
grep -Fq 'iterm: SUCCESS' "$TMP/retry"
[[ -d "$HOME/Applications/iTerm.app" ]]

# A successful apply followed by a failed postcondition maps to CLI code 5.
cat >> "$project/modules/iterm/module.sh" <<'FIXTURE'
if [[ ${MOCK_NO_INSTALL:-0} == 1 ]]; then iterm_install() { return 0; }; fi
FIXTURE
mv "$HOME/Applications/iTerm.app" "$TMP/installed.app"
MOCK_NO_INSTALL=1 expect_error 5 'verify returned 10'
mv "$TMP/installed.app" "$HOME/Applications/iTerm.app"

# Capture command probes independently of which tools the host has installed.
cat >> "$project/lib/common.sh" <<'FIXTURE'
require_command() { echo "$1" >> "$HOME/probes"; return 1; }
FIXTURE
: > "$HOME/downloads"
printf '7\n0\n' | "$project/setup.sh" > "$TMP/menu"
grep -Fq 'iterm: SKIPPED' "$TMP/menu"
MOCK_OS=Linux expect_error 3 'iterm: UNSUPPORTED'
rm -r "$HOME/Applications/iTerm.app"
mkdir "$MOCK_SYSTEM/iTerm2.app"
"$project/setup.sh" install iterm > "$TMP/system-skip"
grep -Fq 'iterm: SKIPPED' "$TMP/system-skip"
[[ ! -e "$HOME/probes" && ! -s "$HOME/downloads" ]]
rmdir "$MOCK_SYSTEM/iTerm2.app"
expect_error 3 'iterm: BLOCKED'
[[ $(cat "$HOME/probes") == curl ]]

echo keep > "$HOME/Applications/iTerm.app"
expect_error 1 'check returned 1'
[[ $(cat "$HOME/Applications/iTerm.app") == keep ]]
rm "$HOME/Applications/iTerm.app"
ln -s "$TMP/missing" "$HOME/Applications/iTerm2.app"
expect_error 1 'check returned 1'
[[ -L "$HOME/Applications/iTerm2.app" && ! -e "$TMP/missing" ]]
rm "$HOME/Applications/iTerm2.app"
rmdir "$HOME/Applications"
ln -s "$MOCK_SYSTEM" "$HOME/Applications"
expect_error 1 'check returned 1'
[[ -L "$HOME/Applications" && -z $(ls -A "$MOCK_SYSTEM") && ! -s "$HOME/downloads" ]]
echo 'PASS: iTerm2 Runner, progress, exit codes, path protection and retry after partial copy'
