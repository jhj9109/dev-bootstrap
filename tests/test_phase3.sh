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
    version)
      if [[ ${MOCK_NEEDS_INSTALL:-0} == 1 && ! -e $HOME/node-installed ]]; then echo N/A; return 3
      else echo v24.0.0; fi ;;
    install) touch "$HOME/node-installed" ;;
    alias|use) return 0;;
    *) return 1;;
  esac
}
MOCK
cat > "$HOME/.local/bin/uv" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == python && "$2" == install ]]; then touch "$HOME/python-installed"; exit $?; fi
if [[ "$1" == python && "$2" == find ]]; then
  if [[ ${MOCK_NEEDS_INSTALL:-0} == 1 && ! -e $HOME/python-installed ]]; then
    echo "error: No interpreter found for Python $3 in managed installations" >&2; exit 2
  fi
  printf '3.12.7\n'; exit 0; fi
exit 1
MOCK
chmod +x "$HOME/.local/bin/uv"
printf '# existing user config\n' > "$HOME/.zshrc"
"$TMP/project/setup.sh" configure shell >/dev/null
"$TMP/project/setup.sh" configure shell >/dev/null
[[ "$(grep -Fc '# Dev Bootstrap managed environment' "$HOME/.zshrc")" == 1 ]]
grep -q 'existing user config' "$HOME/.zshrc"
rm "$HOME/.config/dev-bootstrap/env.zsh"
"$TMP/project/setup.sh" install node --version 24 > "$TMP/node"
grep -Fq 'shell: SUCCESS' "$TMP/node"
rm "$HOME/.config/dev-bootstrap/env.zsh"
"$TMP/project/setup.sh" install python --version 3.12 --method uv > "$TMP/python"
grep -Fq 'shell: SUCCESS' "$TMP/python"
for tool in node npm; do
  printf '#!/bin/sh\necho mock-version\n' > "$HOME/.local/bin/$tool"
  chmod +x "$HOME/.local/bin/$tool"
done
for tool in node python; do
  rm "$HOME/.config/dev-bootstrap/env.zsh"
  PATH="$HOME/.local/bin:$PATH" MOCK_NEEDS_INSTALL=1 "$TMP/project/setup.sh" install "$tool" > "$TMP/install"
  grep -Fq 'shell: SUCCESS' "$TMP/install"
  [[ -e "$HOME/$tool-installed" ]]
done
printf '# user edit\n' >> "$HOME/.config/dev-bootstrap/env.zsh"
for tool in node python; do
  status=0
  "$TMP/project/setup.sh" install "$tool" > "$TMP/error" 2>&1 || status=$?
  [[ $status == 1 ]]
  grep -Fq "$tool: NEEDS_ACTION" "$TMP/error"
done
rm "$HOME/.config/dev-bootstrap/env.zsh"
[[ ! -e "$HOME/Applications" ]]
"$TMP/project/setup.sh" help | grep -q 'Dev Bootstrap v2'
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
