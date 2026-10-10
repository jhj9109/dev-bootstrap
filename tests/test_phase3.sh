#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R "$ROOT" "$TMP/project"
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME/.nvm" "$HOME/.local/bin"
# Mock nvm: no network and no system installations.
cat > "$HOME/.nvm/nvm.sh" <<'MOCK'
nvm() {
  case "$1" in
    version) printf 'v24.0.0\n';;
    alias|use|install) return 0;;
    *) return 1;;
  esac
}
MOCK
cat > "$HOME/.local/bin/uv" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == python && "$2" == find ]]; then printf '/mock/python3.12\n'; exit 0; fi
exit 1
MOCK
chmod +x "$HOME/.local/bin/uv"
printf '# existing user config\n' > "$HOME/.zshrc"
"$TMP/project/setup.sh" configure shell >/dev/null
"$TMP/project/setup.sh" configure shell >/dev/null
[[ "$(grep -Fc '# Dev Bootstrap managed environment' "$HOME/.zshrc")" == 1 ]]
grep -q 'existing user config' "$HOME/.zshrc"
"$TMP/project/setup.sh" install node --version 24 >/dev/null
"$TMP/project/setup.sh" install python --version 3.12 --method uv >/dev/null
[[ ! -e "$HOME/Applications" ]]
"$TMP/project/setup.sh" help | grep -q 'Phase 4'
printf '0\n' | "$TMP/project/setup.sh" >/dev/null
for args in 'install python --version bad' 'install python --method invalid' 'install node --version bad' 'install iterm --version 1' 'configure shell --extra' 'install unknown'; do
  set +e
  # Deliberate argument splitting for the fixed test cases above.
  "$TMP/project/setup.sh" $args >/dev/null 2>&1
  status=$?
  set -e
  [[ "$status" == 2 ]] || { echo "Expected 2, got $status: $args"; exit 1; }
done
# Ensure no actual downloads are performed and no existing files are deleted.
printf 'preserve\n' > "$HOME/.local/bin/keep"
"$TMP/project/setup.sh" configure shell >/dev/null
[[ "$(cat "$HOME/.local/bin/keep")" == preserve ]]
echo 'PASS: Phase 3 CLI, idempotent shell, mocked Node/uv checks, validation, file preservation'
