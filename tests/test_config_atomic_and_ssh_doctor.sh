#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R "$ROOT" "$TMP/project"
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$TMP/mockbin"
cat > "$TMP/project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER=alice
GITHUB_PERSONAL_EMAIL=alice@example.com
CONF
# Verify invalid edits never partially change the active in-memory config.
source "$TMP/project/lib/logger.sh"
source "$TMP/project/lib/config.sh"
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
printf 'private\n' > "$HOME/.ssh/dev-bootstrap-personal"
printf 'public\n' > "$HOME/.ssh/dev-bootstrap-personal.pub"
cat > "$TMP/mockbin/ssh" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_SSH_OUTPUT:-}"
exit "${MOCK_SSH_STATUS:-1}"
MOCK
chmod +x "$TMP/mockbin/ssh"
export PATH="$TMP/mockbin:$PATH"
export MOCK_SSH_OUTPUT="Hi alice! You've successfully authenticated, but GitHub does not provide shell access."
export MOCK_SSH_STATUS=1
"$TMP/project/setup.sh" doctor github --profile personal >/dev/null
MOCK_SSH_STATUS=0
if "$TMP/project/setup.sh" doctor github --profile personal >/dev/null 2>&1; then echo 'FAIL: wrong SSH status accepted'; exit 1; fi
MOCK_SSH_STATUS=1
MOCK_SSH_OUTPUT="Hi alice! You've successfully authenticated, but GitHub does not provide shell access.\nFAKE"
if "$TMP/project/setup.sh" doctor github --profile personal >/dev/null 2>&1; then echo 'FAIL: unexpected output accepted'; exit 1; fi
MOCK_SSH_OUTPUT="Hi mallory! You've successfully authenticated, but GitHub does not provide shell access."
if "$TMP/project/setup.sh" doctor github --profile personal >/dev/null 2>&1; then echo 'FAIL: wrong user accepted'; exit 1; fi
echo 'PASS: atomic config reload and strict SSH doctor responses'
