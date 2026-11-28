#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
bash "$ROOT/tests/copy-project.sh" "$ROOT" "$TMP/project"
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$TMP/mockbin"
cat > "$TMP/project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER=alice
GITHUB_PERSONAL_EMAIL=alice@example.com
CONF
# Verify invalid edits never partially change the active in-memory config.
source "$TMP/project/lib/logger.sh"
source "$TMP/project/lib/config.sh"
source "$TMP/project/core/registry.sh"
source "$TMP/project/modules/workspace.sh"
source "$TMP/project/modules/iterm.sh"
discover_modules "$TMP/project"
load_config "$TMP/project"
[[ "$GITHUB_PERSONAL_USER" == alice && "$NODE_VERSION" == 24 ]]
cat > "$TMP/project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER=bob
NODE_VERSION=invalid
CONF
if load_config "$TMP/project" 2>/dev/null; then echo 'FAIL: invalid config accepted'; exit 1; fi
[[ "$GITHUB_PERSONAL_USER" == alice && "$NODE_VERSION" == 24 ]]
cat > "$TMP/project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER=bob
GITHUB_PERSONAL_EMAIL=bob@example.com
CONF
load_config "$TMP/project"
[[ "$GITHUB_PERSONAL_USER" == bob && "$GITHUB_PERSONAL_EMAIL" == bob@example.com ]]
# Removed fields must not retain old values.
printf 'GITHUB_PERSONAL_USER=carol\n' > "$TMP/project/config/profiles.conf"
load_config "$TMP/project"
[[ "$GITHUB_PERSONAL_USER" == carol && -z "$GITHUB_PERSONAL_EMAIL" ]]
# Simulate GitHub SSH responses, including misleading output and exit codes.
cat > "$TMP/project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER=alice
GITHUB_PERSONAL_EMAIL=alice@example.com
CONF
mkdir -p "$HOME/.ssh"
printf '%s\nfixture-id: personal\n' '-----BEGIN OPENSSH PRIVATE KEY-----' > "$HOME/.ssh/dev-bootstrap-personal"
printf 'ssh-ed25519 personal\n' > "$HOME/.ssh/dev-bootstrap-personal.pub"
cp "$ROOT"/tests/fixtures/github/{ssh,ssh-keygen} "$TMP/mockbin/"
export PATH="$TMP/mockbin:$PATH"
export MOCK_SSH_OUTPUT="Hi alice! You've successfully authenticated, but GitHub does not provide shell access."
export MOCK_SSH_STATUS=1
"$TMP/project/setup.sh" doctor github --profile personal >/dev/null
MOCK_SSH_STATUS=0
if "$TMP/project/setup.sh" doctor github --profile personal >/dev/null 2>&1; then echo 'FAIL: wrong SSH status accepted'; exit 1; fi
MOCK_SSH_STATUS=1
MOCK_SSH_OUTPUT="Hi alice! You've successfully authenticated, but GitHub does not provide shell access.\nFAKE"
if "$TMP/project/setup.sh" doctor github --profile personal >/dev/null 2>&1; then echo 'FAIL: unexpected output accepted'; exit 1; fi
check_warning() {
  local result status=0
  result=$(MOCK_SSH_STATUS="$1" MOCK_SSH_OUTPUT="$2" "$TMP/project/setup.sh" doctor github --profile personal 2>&1) || status=$?
  [[ $status == 4 && $result == *"$3"* && $result != *"$2"* && $result != *private-marker* ]] || {
    echo "FAIL: expected doctor exit 4 and warning containing '$3'"; exit 1
  }
}
check_warning 1 "Hi private-marker! You've successfully authenticated, but GitHub does not provide shell access." 'different account'
check_warning 255 $'No ED25519 host key is known for github.com and you have requested strict checking.\nHost key verification failed.' 'No trusted GitHub host key'
check_warning 255 $'@ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! @\nOffending key in private-marker' 'host key mismatch'
check_warning 255 'git@github.com: Permission denied (publickey).' 'public key authentication failed'
check_warning 255 'ssh: Could not resolve hostname github.com: private-marker' 'Check DNS'
check_warning 255 'ssh: connect to host github.com port 22: Operation timed out' 'port 22'
check_warning 255 'Host key verification failed.' 'did not confirm'
check_warning 1 'git@github.com: Permission denied (publickey).' 'did not confirm'
echo 'PASS: atomic config reload and strict SSH doctor responses'
