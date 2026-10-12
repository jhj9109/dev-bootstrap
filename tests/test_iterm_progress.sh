#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home"
export HOME="$TMP/home" PATH="$TMP/bin:$PATH" GIT_CONFIG_NOSYSTEM=1
cat > "$TMP/bin/uname" <<'MOCK'
#!/usr/bin/env bash
printf 'Darwin\n'
MOCK
cat > "$TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
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
  mkdir -p "$4/iTerm.app"
else
  mkdir -p "$2"
fi
MOCK
chmod +x "$TMP/bin/"*
"$ROOT/setup.sh" install iterm > "$TMP/output" 2>&1
grep -q 'downloading stable release' "$TMP/output"
grep -q 'download complete' "$TMP/output"
grep -q 'extracting archive' "$TMP/output"
grep -q 'copying application' "$TMP/output"
grep -q 'installed in ~/Applications' "$TMP/output"
grep -qx -- '--speed-limit' "$HOME/curl-args"
grep -qx -- '--speed-time' "$HOME/curl-args"
grep -qx -- '--connect-timeout' "$HOME/curl-args"
[[ -d "$HOME/Applications/iTerm.app" ]]
"$ROOT/setup.sh" install iterm > "$TMP/again" 2>&1
grep -q 'already installed' "$TMP/again"
rm -rf "$HOME/Applications"
MOCK_CURL_FAIL=1 "$ROOT/setup.sh" install iterm > "$TMP/failure" 2>&1 && { echo 'Expected download failure'; exit 1; }
grep -q 'download failed' "$TMP/failure"
[[ ! -e "$HOME/Applications/iTerm.app" ]]
echo 'PASS: iTerm2 progress stages, curl safeguards, idempotency, failure reporting'
