#!/usr/bin/env bash
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
project="$tmp/project"
dir="$HOME/.ssh"
orb="$HOME/.orbstack/ssh/config"
mkdir -p "$dir" "${orb%/*}" "$project" "$tmp/bin"
bash "$root/tests/copy-project.sh" "$root" "$project"
cd "$project"
cat > config/accounts.conf <<'CONF'
GITHUB_PERSONAL_USER=alice
GITHUB_PERSONAL_EMAIL=alice@example.com
GITHUB_SECONDARY_USER=bob
GITHUB_SECONDARY_EMAIL=bob@example.com
CONF
cat > "$dir/config" <<'CONF'
# Added by OrbStack: 'orb' SSH host for Linux machines
# This only works if it's at the top of ssh_config (before any Host blocks).
# This won't be added again if you remove it.
Include ~/.orbstack/ssh/config
CONF
cp "$dir/config" "$tmp/original"
cp "$root/tests/fixtures/orbstack/config" "$orb"
# OpenSSH expands Include ~ using passwd, not HOME. Map only the two literal
# includes to their temporary paths for an independent read of the published files.
effective() {
  sed "s|^Include ~/|Include \"$HOME/|; /^Include /s/$/\"/" "$dir/config" |
    /usr/bin/ssh -G -F /dev/stdin "$1" 2>/dev/null
}
effective orb > "$tmp/before"
grep -qx 'hostname 127.0.0.1' "$tmp/before"
grep -qx 'port 32222' "$tmp/before"
grep -q '^proxycommand .*ssh-proxy-fdpass ' "$tmp/before"
expect() {
  local rc=0 want=$1 status=$2
  shift 2
  ./setup.sh "$@" > "$tmp/out" 2>&1 || rc=$?
  if [[ $rc != "$want" ]] || ! grep -Fq "$status" "$tmp/out"; then cat "$tmp/out"; return 1; fi
}
expect 1 CHANGE_NEEDED check github --profile personal --method ssh --no-passphrase
for profile in personal secondary; do
  expect 0 SUCCESS configure github --profile "$profile" --no-passphrase
  expect 0 SKIPPED check github --profile "$profile"
  expect 0 SKIPPED configure github --profile "$profile"
  if [[ $profile == personal ]]; then
    cp "$dir/dev-bootstrap-personal" "$tmp/original-key"
  else
    cmp "$dir/dev-bootstrap-personal" "$tmp/original-key"
  fi
  effective "github-$profile" > "$tmp/alias"
  grep -qx 'hostname github.com' "$tmp/alias"
  grep -qx 'port 22' "$tmp/alias"
  grep -qx 'user git' "$tmp/alias"
  grep -qx 'identitiesonly yes' "$tmp/alias"
  [[ $(grep -c '^identityfile ' "$tmp/alias") == 1 ]]
  grep -Fxq "identityfile $dir/dev-bootstrap-$profile" "$tmp/alias"
  ! grep -Ei 'orbstack|^proxycommand |^proxyusefdpass yes' "$tmp/alias" || exit 1
done
effective orb > "$tmp/after"
cmp "$tmp/before" "$tmp/after"
cmp "$orb" "$root/tests/fixtures/orbstack/config"
{ cat "$tmp/original"; echo 'Include ~/.ssh/dev-bootstrap.conf'; } > "$tmp/expected"
cmp "$dir/config" "$tmp/expected"
expect 0 'github: SKIPPED' all --environment minimal --profile personal
cp "$root/tests/fixtures/github/ssh" "$tmp/bin/"
export PATH="$tmp/bin:$PATH"
export MOCK_SSH_OUTPUT="Hi alice! You've successfully authenticated, but GitHub does not provide shell access."
expect 0 'authenticated as alice' doctor github --profile personal
for bad in 'Include more.conf' 'Host *' 'Match exec "false"' 'Port 22'; do
  cp "$root/tests/fixtures/orbstack/config" "$orb"
  echo "$bad" >> "$orb"
  expect 4 NEEDS_ACTION configure github
  expect 4 'Review SSH' doctor github
done
cp "$root/tests/fixtures/orbstack/config" "$orb"
for directive in 'Include ~/.ssh/dev-bootstrap.conf' 'Host *' 'Match all'; do
  { echo "$directive"; cat "$tmp/original"; } > "$dir/config"
  expect 4 NEEDS_ACTION configure github
done
cp "$tmp/expected" "$dir/config"
# Simulate an external rewrite between inspection and publication.
mv "$dir/dev-bootstrap.conf" "$tmp/managed"
sed '/^Host github-secondary/,$d' "$tmp/managed" > "$dir/dev-bootstrap.conf"
cp "$dir/dev-bootstrap.conf" "$tmp/personal"
cat > "$tmp/bin/ssh" <<'SH'
#!/bin/sh
if test -d "$HOME/.ssh/.dev-bootstrap.lock"; then
  echo 'Match exec "false"' >> "$HOME/.orbstack/ssh/config"
fi
exec /usr/bin/ssh "$@"
SH
expect 4 NEEDS_ACTION configure github --profile secondary
cmp "$dir/dev-bootstrap.conf" "$tmp/personal"
rm "$orb"
ln -s "$root/tests/fixtures/orbstack/config" "$orb"
expect 4 NEEDS_ACTION configure github
cmp "$dir/config" "$tmp/expected"
[[ $(wc -l < "$HOME/ssh-trace") -eq 1 ]]
echo 'PASS: scoped OrbStack Include and isolated GitHub profiles'
