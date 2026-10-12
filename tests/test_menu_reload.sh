#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap '[[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null || :; rm -rf "$TMP"' EXIT
cp -R "$ROOT" "$TMP/project"
mkdir -p "$TMP/home"
cat > "$TMP/project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER="first-user"
GITHUB_PERSONAL_EMAIL="first@example.com"
CONF
mkfifo "$TMP/input"
HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1 "$TMP/project/setup.sh" < "$TMP/input" > "$TMP/output" 2>&1 &
pid=$!
exec 3> "$TMP/input"
printf '2\n' >&3
for i in {1..100}; do
  [[ "$(HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1 git config --global user.name 2>/dev/null || :)" == first-user ]] && break
  sleep 0.03
done
[[ "$(HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1 git config --global user.name)" == first-user ]]
cat > "$TMP/project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER="second-user"
GITHUB_PERSONAL_EMAIL="second@example.com"
CONF
printf '2\n0\n' >&3
exec 3>&-
wait "$pid"
pid=''
[[ "$(HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1 git config --global user.name)" == second-user ]]
[[ "$(HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1 git config --global user.email)" == second@example.com ]]
echo 'PASS: interactive menu reloads edited profile config without restart'
