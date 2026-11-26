#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
TMP="$(cd -P "$TMP" && pwd)"
trap 'rm -rf "$TMP"' EXIT
cp -R "$ROOT" "$TMP/project"
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$TMP/fixture"
cat > "$TMP/project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER="test-user"
GITHUB_PERSONAL_EMAIL="test@example.com"
GITHUB_SECONDARY_USER="second-user"
GITHUB_SECONDARY_EMAIL="second@example.com"
CONF
# Workspace: first run, second run, no data loss
"$TMP/project/setup.sh" configure workspace >/dev/null
printf 'keep\n' > "$HOME/Documents/keep.txt"
"$TMP/project/setup.sh" configure workspace >/dev/null
[[ "$(cat "$HOME/Documents/keep.txt")" == keep ]]
# Clone and all still call the legacy Workspace function. Make an accidental
# dispatch through the registered check fail in this temporary project.
printf '\nworkspace_status() { return 23; }\n' >> "$TMP/project/modules/workspace/module.sh"
# Real local Git fixture; exercise remote changes without contacting GitHub.
git init -q "$TMP/fixture"
"$TMP/project/setup.sh" repo remote owner/project --repo "$TMP/fixture" --profile personal >/dev/null
[[ "$(git -C "$TMP/fixture" remote get-url origin)" == 'git@github-personal:owner/project.git' ]]
"$TMP/project/setup.sh" repo remote owner/project --repo "$TMP/fixture" --profile personal >/dev/null
if "$TMP/project/setup.sh" repo remote other/project --repo "$TMP/fixture" >/dev/null 2>&1; then echo 'unexpected remote overwrite'; exit 1; fi
[[ "$(git -C "$TMP/fixture" remote get-url origin)" == 'git@github-personal:owner/project.git' ]]
"$TMP/project/setup.sh" repo remote owner/project --repo "$TMP/fixture" --name backup --method gh >/dev/null
[[ "$(git -C "$TMP/fixture" remote get-url backup)" == 'https://github.com/owner/project.git' ]]
# Clone: use Git URL rewrite to map a GitHub URL to local fixture (offline).
git -C "$TMP/fixture" -c user.name=Test -c user.email=test@example.com commit -q --allow-empty -m initial
git config --global url."file://$TMP/fixture".insteadOf 'https://github.com/owner/project.git'
"$TMP/project/setup.sh" repo clone owner/project --method gh >/dev/null
"$TMP/project/setup.sh" repo clone owner/project --method gh >/dev/null
[[ -d "$HOME/Documents/project/.git" ]]
[[ "$(git -C "$HOME/Documents/project" config --local --get remote.origin.url)" == 'https://github.com/owner/project.git' ]]
for spec in '../bad' 'owner/../bad' 'owner/bad/path'; do
  if "$TMP/project/setup.sh" repo clone "$spec" --method gh >/dev/null 2>&1; then echo "unexpected accepted spec: $spec"; exit 1; fi
done
if "$TMP/project/setup.sh" repo clone owner/project --method gh --dest relative >/dev/null 2>&1; then echo 'relative path accepted'; exit 1; fi
if "$TMP/project/setup.sh" repo remote owner/project >/dev/null 2>&1; then echo 'missing repo accepted'; exit 1; fi
# all: disable network installers; use mocked ssh and a temporary HOME.
cat >> "$TMP/project/config/defaults.conf" <<'CONF'
INSTALL_NODE=false
INSTALL_PYTHON=false
INSTALL_ITERM=false
CONF
mkdir -p "$TMP/mockbin"
cp "$ROOT"/tests/fixtures/github/{ssh,ssh-keygen} "$TMP/mockbin/"
export PATH="$TMP/mockbin:$PATH"
"$TMP/project/setup.sh" all --profile personal --no-passphrase >/dev/null
# Keep the enabled runtime and application modules offline on the second run.
mkdir -p "$HOME/.nvm"
cat > "$HOME/.nvm/nvm.sh" <<'MOCK'
[[ $1 == --no-use ]] || return 1
nvm() { [[ $1 == version ]] && echo v24.7.3; }
MOCK
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/uv" <<'MOCK'
#!/bin/sh
[ "$1 $2" = "python find" ] && echo 3.12.7
MOCK
chmod +x "$HOME/.local/bin/uv"
printf 'INSTALL_PYTHON=true\n' >> "$TMP/project/config/defaults.conf"
printf 'INSTALL_NODE=true\n' >> "$TMP/project/config/defaults.conf"
printf 'INSTALL_ITERM=true\n' >> "$TMP/project/config/defaults.conf"
printf '\niterm_system_installed() { return 0; }\n' >> "$TMP/project/modules/iterm.sh"
printf '#!/bin/sh\necho Darwin\n' > "$TMP/mockbin/uname"
chmod +x "$TMP/mockbin/uname"
"$TMP/project/setup.sh" all --profile personal --no-passphrase > "$TMP/all-output"
grep -Fq 'shell: SKIPPED' "$TMP/all-output"
grep -Fq 'python: SKIPPED' "$TMP/all-output"
grep -Fq 'node: SKIPPED' "$TMP/all-output"
grep -Fq 'github: SKIPPED' "$TMP/all-output"
grep -Fq 'git: SKIPPED' "$TMP/all-output"
grep -Fq "iterm: SKIPPED" "$TMP/all-output"
[[ -f "$HOME/.ssh/dev-bootstrap-personal" ]]
[[ "$(grep -Fc '# Dev Bootstrap managed environment' "$HOME/.zshrc")" == 1 ]]
[[ "$(cat "$HOME/Documents/keep.txt")" == keep ]]
echo 'PASS: Phase 4 workspace, offline clone, remote, validation, idempotency, all orchestration'
