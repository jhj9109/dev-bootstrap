#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
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
cat > "$TMP/mockbin/ssh-keygen" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == -l ]]; then [[ -f "$3" ]]; exit $?; fi
if [[ "$1" == -y ]]; then printf 'ssh-ed25519 MOCKPUB\n'; exit 0; fi
while (( $# )); do if [[ "$1" == -f ]]; then shift; key="$1"; fi; shift; done
printf 'MOCKPRIVATE\n' > "$key"
printf 'ssh-ed25519 MOCKPUB\n' > "$key.pub"
MOCK
cat > "$TMP/mockbin/ssh" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == -G ]]; then printf 'hostname github.com\n'; exit 0; fi
exit 1
MOCK
chmod +x "$TMP/mockbin/ssh" "$TMP/mockbin/ssh-keygen"
export PATH="$TMP/mockbin:$PATH"
"$TMP/project/setup.sh" all --profile personal --no-passphrase >/dev/null
"$TMP/project/setup.sh" all --profile personal --no-passphrase >/dev/null
[[ -f "$HOME/.ssh/dev-bootstrap-personal" ]]
[[ "$(grep -Fc '# Dev Bootstrap managed environment' "$HOME/.zshrc")" == 1 ]]
[[ "$(cat "$HOME/Documents/keep.txt")" == keep ]]
echo 'PASS: Phase 4 workspace, offline clone, remote, validation, idempotency, all orchestration'
