#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R "$ROOT" "$TMP/project"
cat > "$TMP/project/config/profiles.conf" <<'CONFIG'
GITHUB_PERSONAL_USER="test-user"
GITHUB_PERSONAL_EMAIL="test@example.com"
GITHUB_SECONDARY_USER="second-user"
GITHUB_SECONDARY_EMAIL="second@example.com"
CONFIG
# This CI container lacks OpenSSH; simulate ssh-keygen/ssh to test orchestration.
mkdir -p "$TMP/mockbin"
cat > "$TMP/mockbin/ssh-keygen" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == -l ]]; then [[ -f "$3" ]]; exit $?; fi
if [[ "$1" == -y ]]; then printf 'ssh-ed25519 MOCKPUB\n'; exit 0; fi
while (( $# )); do
  if [[ "$1" == -f ]]; then shift; key="$1"; fi
  shift
done
printf 'MOCKPRIVATE\n' > "$key"
printf 'ssh-ed25519 MOCKPUB\n' > "$key.pub"
MOCK
cat > "$TMP/mockbin/ssh" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == -G ]]; then printf 'hostname github.com\n'; exit 0; fi
exit 1
MOCK
chmod +x "$TMP/mockbin/ssh-keygen" "$TMP/mockbin/ssh"
export PATH="$TMP/mockbin:$PATH"
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME/.ssh" "$TMP/repo"
printf 'Host custom\n  HostName example.org\n' > "$HOME/.ssh/config"
printf 'important\n' > "$HOME/.ssh/keep.txt"
git init -q "$TMP/repo"
"$TMP/project/setup.sh" configure git --profile personal >/dev/null
[[ "$(git config --global user.name)" == test-user ]]
"$TMP/project/setup.sh" configure git --profile secondary --repo "$TMP/repo" >/dev/null
[[ "$(git -C "$TMP/repo" config --local user.name)" == second-user ]]
[[ "$(git config --global user.name)" == test-user ]]
"$TMP/project/setup.sh" configure github --profile personal --no-passphrase >/dev/null
keysum="$(shasum -a 256 "$HOME/.ssh/dev-bootstrap-personal" | awk '{print $1}')"
"$TMP/project/setup.sh" configure github --profile personal --no-passphrase >/dev/null
[[ "$keysum" == "$(shasum -a 256 "$HOME/.ssh/dev-bootstrap-personal" | awk '{print $1}')" ]]
[[ "$(grep -Fc 'Include ~/.ssh/dev-bootstrap.conf' "$HOME/.ssh/config")" == 1 ]]
[[ "$(cat "$HOME/.ssh/keep.txt")" == important ]]
grep -q 'Host custom' "$HOME/.ssh/config"
"$TMP/project/setup.sh" configure github --profile secondary --no-passphrase >/dev/null
grep -q 'Host github-personal' "$HOME/.ssh/dev-bootstrap.conf"
grep -q 'Host github-secondary' "$HOME/.ssh/dev-bootstrap.conf"
[[ "$(stat -c %a "$HOME/.ssh" 2>/dev/null || stat -f %Lp "$HOME/.ssh")" == 700 ]]
set +e
"$TMP/project/setup.sh" configure github --profile unknown --no-passphrase >"$TMP/err" 2>&1
status=$?
set -e
[[ "$status" == 2 ]]
[[ -f "$HOME/.ssh/dev-bootstrap-personal" ]]
echo 'PASS: Git global/local, SSH two profiles, key preservation, config preservation, idempotency, validation'
