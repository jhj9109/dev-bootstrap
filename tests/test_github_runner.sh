#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1 PATH="$root/tests/fixtures/github:$PATH"
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
project="$tmp/project"
mkdir -p "$HOME" "$project" "$tmp/outside"
cp -R "$root"/{setup.sh,bootstrap.sh,core,lib,modules,config} "$project/"
cat > "$project/config/accounts.conf" <<'CONF'
GITHUB_PERSONAL_USER=alice
GITHUB_PERSONAL_EMAIL=alice@example.com
GITHUB_SECONDARY_USER=bob
GITHUB_SECONDARY_EMAIL=second@example.com
CONF
cd "$tmp"
expect_cli() {
  local want=$1 msg=$2 rc=0
  shift 2
  "$project/bootstrap.sh" "$@" </dev/null > "$tmp/out" 2>&1 || rc=$?
  if [[ $rc != "$want" ]] || { [[ -n $msg ]] && ! grep -Fq "$msg" "$tmp/out"; } || grep -Fq fixture-sensitive-diagnostic "$tmp/out"; then
    echo "Expected exit $want ($msg), got $rc" >&2; return 1
  fi
}
ssh_args=(configure github --method ssh)
gh_args=(configure github --method gh)
dir="$HOME/.ssh"
key="$dir/dev-bootstrap-personal"
expect_cli 4 NEEDS_ACTION "${ssh_args[@]}"
[[ ! -e $dir ]]
expect_cli 0 SUCCESS "${ssh_args[@]}" --no-passphrase
grep -Fq "$key.pub" "$tmp/out"
cp "$key" "$tmp/original-key"
cp "$key.pub" "$tmp/original-pub"
touch -t 200001010101 "$dir/config" "$dir/dev-bootstrap.conf" "$key" "$key.pub" "$tmp/time"
expect_cli 0 SKIPPED "${ssh_args[@]}"
grep -Fq 'doctor github --method ssh --profile personal' "$tmp/out"
for path in "$dir/config" "$dir/dev-bootstrap.conf" "$key" "$key.pub"; do [[ ! $path -nt $tmp/time ]]; done
[[ ! -e "$HOME/ssh-trace" && $(cat "$HOME/keygen-trace") == generated ]]
cp "$dir/dev-bootstrap.conf" "$tmp/personal-only"
cp "$dir/config" "$tmp/original-config"
# The candidate parses, but the live configuration fails after publication.
MOCK_LIVE_USER=root expect_cli 5 'apply returned 5' "${ssh_args[@]}" --profile secondary --no-passphrase
cmp "$dir/dev-bootstrap.conf" "$tmp/personal-only"
cmp "$dir/config" "$tmp/original-config"
expect_cli 0 SUCCESS "${ssh_args[@]}" --profile secondary --no-passphrase
cmp "$key" "$tmp/original-key"; cmp "$key.pub" "$tmp/original-pub"
cp "$dir/dev-bootstrap-secondary.pub" "$key.pub"
expect_cli 1 'check returned 1' "${ssh_args[@]}"
cmp "$key.pub" "$dir/dev-bootstrap-secondary.pub"
rm "$key.pub"
MOCK_RECOVERY=fail expect_cli 4 NEEDS_ACTION "${ssh_args[@]}"
[[ ! -e $key.pub && ! -e $dir/.dev-bootstrap.lock ]]
expect_cli 0 SUCCESS "${ssh_args[@]}"
cmp "$key.pub" "$tmp/original-pub"
[[ $(wc -l < "$HOME/keygen-trace") -eq 2 ]]
rm "$key.pub"; ln -s "$tmp/outside/target" "$key.pub"
expect_cli 1 'check returned 1' "${ssh_args[@]}"
[[ -L $key.pub && ! -e $tmp/outside/target ]]
rm "$key.pub"; cp "$tmp/original-pub" "$key.pub"
mv "$dir" "$tmp/ssh-dir"; ln -s "$tmp/ssh-dir" "$dir"
expect_cli 1 'check returned 1' "${ssh_args[@]}"
rm "$dir"; mv "$tmp/ssh-dir" "$dir"

cp "$dir/config" "$tmp/config"
echo 'Include ~/.ssh/dev-bootstrap.conf' >> "$dir/config"
expect_cli 4 NEEDS_ACTION "${ssh_args[@]}"
cp "$tmp/config" "$dir/config"
echo 'Include ~/.ssh/*.conf' >> "$dir/config"
expect_cli 4 NEEDS_ACTION "${ssh_args[@]}"
cp "$tmp/config" "$dir/config"
cp "$dir/dev-bootstrap.conf" "$tmp/managed"
echo '# user edit' >> "$dir/dev-bootstrap.conf"
expect_cli 4 NEEDS_ACTION "${ssh_args[@]}"
grep -q '^# user edit' "$dir/dev-bootstrap.conf"
cp "$tmp/managed" "$dir/dev-bootstrap.conf"
echo 'Host github-personal' >> "$dir/config"
expect_cli 4 NEEDS_ACTION "${ssh_args[@]}"
cp "$tmp/config" "$dir/config"
MOCK_EXTRA_IDENTITY=1 expect_cli 5 'check returned 5' "${ssh_args[@]}"
MOCK_SSH_HOST=other.invalid expect_cli 5 'check returned 5' "${ssh_args[@]}"
MOCK_SSH_USER=root expect_cli 5 'check returned 5' "${ssh_args[@]}"
export MOCK_SSH_OUTPUT="Hi alice! You've successfully authenticated, but GitHub does not provide shell access."
expect_cli 0 'authenticated as alice' doctor github
MOCK_SSH_OUTPUT='fixture-sensitive-diagnostic' expect_cli 4 'did not confirm' doctor github
printf '3\n4\n0\n' | "$project/setup.sh" > "$tmp/menu"
grep -q 'github: SKIPPED' "$tmp/menu"
grep -q 'authenticated as alice' "$tmp/menu"
cmp "$key" "$tmp/original-key"; cmp "$dir/config" "$tmp/config"; cmp "$dir/dev-bootstrap.conf" "$tmp/managed"

expect_cli 2 '' "${gh_args[@]}" --no-passphrase
expect_cli 4 NEEDS_ACTION "${gh_args[@]}"
expect_cli 4 '' doctor github --method gh
[[ ! -e $HOME/gh-writes ]]
echo bob > "$HOME/active"
expect_cli 4 NEEDS_ACTION "${gh_args[@]}"
expect_cli 4 'Select GitHub account' doctor github --method gh
echo alice > "$HOME/active"
GH_FAULT=status expect_cli 1 'check returned 1' "${gh_args[@]}"
GH_FAULT=api expect_cli 1 'Cannot query' doctor github --method gh
GH_FAULT=api expect_cli 1 'check returned 1' "${gh_args[@]}"
helper=credential.https://github.com.helper
git config --global credential.helper custom-global
git config --global "$helper" custom-host
expect_cli 4 NEEDS_ACTION "${gh_args[@]}"
[[ ! -e $HOME/gh-writes && $(git config --global "$helper") == custom-host ]]
git config --global --unset-all "$helper"
git config --global credential.https://gist.github.com.helper custom-gist
expect_cli 4 NEEDS_ACTION "${gh_args[@]}"
[[ ! -e $HOME/gh-writes && $(git config --global credential.https://gist.github.com.helper) == custom-gist ]]
git config --global --unset-all credential.https://gist.github.com.helper
GH_FAULT=apply expect_cli 1 'apply returned 1' "${gh_args[@]}"
GH_FAULT=no-write expect_cli 5 'verify returned 10' "${gh_args[@]}"
expect_cli 0 SUCCESS "${gh_args[@]}"
: > "$HOME/gh-writes"
cp "$HOME/.gitconfig" "$tmp/gitconfig"
expect_cli 0 SKIPPED "${gh_args[@]}"
expect_cli 0 'authenticated as alice' doctor github --method gh
[[ ! -s $HOME/gh-writes && $(git config --global credential.helper) == custom-global ]]
cmp "$tmp/gitconfig" "$HOME/.gitconfig"
# A local helper must not be overwritten or mistaken for the global gh setup.
git init -q "$tmp/repo"
(
  cd "$tmp/repo"
  git config --local "$helper" custom-local
  expect_cli 4 NEEDS_ACTION "${gh_args[@]}"
  [[ $(git config --local "$helper") == custom-local && ! -s $HOME/gh-writes ]]
)
# Exercise the permitted interactive login under a pseudoterminal, using only the mock gh.
rm "$HOME/active" "$HOME/.gitconfig"
export MOCK_PROJECT="$project"
if [[ $(uname -s) == Darwin ]]; then
  script -q /dev/null "$project/setup.sh" configure github --method gh </dev/null > "$tmp/tty"
else
  script -qe -c '"$MOCK_PROJECT/setup.sh" configure github --method gh' /dev/null </dev/null > "$tmp/tty"
fi
grep -q 'github: SUCCESS' "$tmp/tty"
[[ $(cat "$HOME/gh-writes") == $'login\nsetup' ]]
printf '\nrequire_command() { [[ $1 != gh ]]; }\n' >> "$project/lib/common.sh"
expect_cli 3 BLOCKED "${gh_args[@]}"
echo 'PASS: GitHub SSH and gh strategies, local skip, key recovery, conflicts, exit codes and authentication-only doctor'
