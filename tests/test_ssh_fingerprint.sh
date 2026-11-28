#!/usr/bin/env bash
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/lib/logger.sh"
source "$root/modules/auth/ssh.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
export HOME=$tmp TMPDIR=$tmp/staging
mkdir -m 700 "$TMPDIR"
# Inspect the actual directory while the alias exists. OpenSSH runs unmodified.
ln() {
  command ln "$@" || return 1
  [[ $1 == -s && -L $3 && ! -e $3.pub ]] || return 1
  [[ $(LC_ALL=C ls -ld "${3%/*}") == drwx------* ]]
}
ssh-keygen -q -t ed25519 -N '' -f plain
ssh-keygen -q -t ed25519 -N fixture -f encrypted
for key in plain encrypted; do
  expected=$(ssh-keygen -l -E sha256 -f "$key.pub" | awk '{print $2}')
  mv "$key.pub" "$key.public"
  actual=$(ssh_fingerprint "$key" </dev/null)
  [[ $actual == "$expected" ]]
  ssh_public_matches "$key.public" "$actual"
done
cp encrypted.public plain.pub
before=$(cksum plain plain.pub)
actual=$(ssh_fingerprint plain)
if ssh_public_matches plain.pub "$actual"; then exit 1; fi
touch invalid
if ssh_fingerprint invalid; then exit 1; fi
[[ $(cksum plain plain.pub) == "$before" && -z $(ls -A "$TMPDIR") ]]
