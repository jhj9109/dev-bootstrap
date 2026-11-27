#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
tmp=$(cd -P "$tmp" && pwd)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file GIT_TERMINAL_PROMPT=0
REAL_GIT=$(command -v git)
export REAL_GIT TRACE="$tmp/writes"
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
project="$tmp/project"
list="$project/config/repositories.conf"
workspace="$HOME/Work Area"
mkdir -p "$project" "$HOME" "$tmp/bin" "$tmp/remotes" "$tmp/outside"
cp -R "$root"/{setup.sh,bootstrap.sh,core,lib,modules,config} "$project/"
cat > "$project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER=alice
GITHUB_PERSONAL_EMAIL=a@example.com
GITHUB_SECONDARY_USER=bob
GITHUB_SECONDARY_EMAIL=b@example.com
WORKSPACE_DIR="$HOME/Work Area"
INSTALL_NODE=false
INSTALL_PYTHON=false
INSTALL_ITERM=false
CONF
cd "$tmp"
git init -q source
git -C source -c user.name=Test -c user.email=test@example.com commit -qm initial --allow-empty
for name in one two; do git clone -q --bare source "remotes/$name.git"; done
git config --global url."file://$tmp/remotes/".insteadOf https://github.com/class/
git config --global --add url."file://$tmp/remotes/".insteadOf git@github-secondary:class/
cp "$root"/tests/fixtures/github/{ssh,ssh-keygen} "$tmp/bin/"
cat > "$tmp/bin/git" <<'MOCK'
#!/usr/bin/env bash
if [[ $1 == clone ]]; then
  echo clone >> "$TRACE"
  if [[ ${FAULT:-} == second && ${!#} == */two ]]; then exit 1; fi
  case ${FAULT:-} in
    partial) mkdir -p "${!#}/.git"; echo incomplete > "${!#}/partial"; echo fixture-private >&2; exit 1 ;;
    wrong) "$REAL_GIT" "$@" && "$REAL_GIT" -C "${!#}" config remote.origin.url wrong; exit $? ;;
  esac
fi
if [[ $1 == -C && $3 == config && " $* " == *' --get-all '* && ${FAULT:-} == query ]]; then
  echo fixture-private >&2; exit 1
fi
if [[ $1 == -C && $3 == remote && ${4:-} == add ]]; then
  echo add >> "$TRACE"
  if [[ ${FAULT:-} == noadd ]]; then exit 0; fi
fi
exec "$REAL_GIT" "$@"
MOCK
chmod +x "$tmp/bin/git"
export PATH="$tmp/bin:$PATH"
: > "$TRACE"

expect() {
  local want=$1 rc=0
  shift
  "$@" > "$tmp/output" 2>&1 || rc=$?
  if [[ $rc != "$want" ]] || grep -Fq fixture-private "$tmp/output"; then
    echo "Expected exit $want, got $rc; check repository diagnostics" >&2; return 1
  fi
}
cli="$project/bootstrap.sh"
# Call the actual registered check/verify without preceding Workspace setup.
ROOT_DIR=$project
source "$project/lib/logger.sh"
source "$project/lib/common.sh"
source "$project/lib/profiles.sh"
source "$project/lib/config.sh"
source "$project/modules/iterm.sh"
source "$project/modules/workspace.sh"
source "$project/modules/repository.sh"
source "$project/core/registry.sh"
source "$project/core/runner.sh"
discover_modules "$project"
load_config "$project"
repository_method=gh
index=$(registry_index repository)
expect 0 runner_run repository
grep -Fq 'repository: SKIPPED' "$tmp/output"
printf ' class/one  # first\r\n\nclass/two' > "$list"
expect 10 "${REGISTRY_CHECK[index]}"
expect 10 "${REGISTRY_VERIFY[index]}"
[[ ! -e $workspace && ! -s $TRACE ]]
for bad in 'class/one' 'other/one' 'other/ONE' 'bad input' '../bad' 'owner/.git'; do
  printf 'class/one\n%s\n' "$bad" > "$list"
  expect 2 "${REGISTRY_CHECK[index]}"
  expect 2 "$cli" all --no-passphrase
  [[ ! -e $workspace && ! -e $HOME/.ssh && ! -s $TRACE ]]
done
printf ' # comment\nclass/one\n class/two # second' > "$list"
mkdir "$workspace"
echo keep > "$workspace/two"
expect 1 runner_run repository
grep -Fq 'check returned 1' "$tmp/output"
[[ ! -s $TRACE && ! -e $workspace/one && $(cat "$workspace/two") == keep ]]
rm "$workspace/two"
rmdir "$workspace"
# Change the manifest during Workspace apply, before Repository's first hook.
# Two restores must still use the original snapshot, with a single Workspace mkdir.
cp "$list" "$tmp/planned-list"
cat > "$tmp/bin/mkdir" <<'MOCK'
#!/bin/sh
if [ "$1" = -p ] && [ "$2" = -- ] && [ "$3" = "$HOME/Work Area" ]; then
  echo mkdir >> "$TRACE"
  echo 'changed/during-run' > "$MANIFEST"
fi
exec /bin/mkdir "$@"
MOCK
chmod +x "$tmp/bin/mkdir"
export MANIFEST="$list"
expect 0 "$cli" all --profile secondary --no-passphrase
grep -Fq 'repository: SUCCESS' "$tmp/output"
[[ $(cat "$TRACE") == $'mkdir\nclone\nclone' && $(cat "$list") == 'changed/during-run' ]]
mv "$tmp/planned-list" "$list"
rm "$tmp/bin/mkdir"
for name in one two; do
  [[ $(git -C "$workspace/$name" config remote.origin.url) == "git@github-secondary:class/$name.git" ]]
done
# Use the same selected account in the actual menu, and preserve a dirty tree.
echo DEFAULT_GITHUB_PROFILE=secondary >> "$project/config/profiles.conf"
echo keep > "$workspace/one/notes"
git -C "$workspace/one" config project.example keep
cp "$workspace/one/.git/config" "$tmp/before"
: > "$TRACE"
printf '10\n0\n' | "$project/setup.sh" > "$tmp/menu"
grep -Fq 'repository: SKIPPED' "$tmp/menu"
[[ ! -s $TRACE && $(cat "$workspace/one/notes") == keep ]]
cmp "$tmp/before" "$workspace/one/.git/config"

# With the same account, minimal omits restoration even with a broken manifest.
cp "$list" "$tmp/valid-list"
printf '../invalid\n' > "$list"
expect 0 "$cli" all --environment minimal --profile secondary --no-passphrase
grep -Fq 'git: SKIPPED' "$tmp/output"
grep -Fq 'github: SKIPPED' "$tmp/output"
if grep -Eq '(repository|node|python|iterm):' "$tmp/output"; then exit 1; fi
[[ ! -s $TRACE ]]
mv "$tmp/valid-list" "$list"

# A wrong, missing, or unreadable origin cannot trigger a clone in another row.
printf 'class/missing\nclass/one\n' > "$list"
repository_method=ssh repository_profile=secondary
git -C "$workspace/one" config remote.origin.url https://fixture-private@example.invalid/repo
expect 1 runner_run repository
[[ $(git -C "$workspace/one" config remote.origin.url) == *fixture-private* ]]
git -C "$workspace/one" config --unset remote.origin.url
expect 1 runner_run repository
grep -Fq 'no origin URL' "$tmp/output"
cp "$tmp/before" "$workspace/one/.git/config"
FAULT=query expect 1 runner_run repository
grep -Fq 'Cannot read remote' "$tmp/output"
[[ ! -s $TRACE && ! -e $workspace/missing ]]
# Dedicated requests can use an independent destination and linked worktree.
explicit="$tmp/outside/explicit"
clone=(repo clone class/one --method gh --dest)
remote=(repo remote class/one --method gh --name backup --repo)
# Explicit destinations also work when the default Workspace cannot be created.
ln -s "$tmp/outside" "$HOME/alias"
echo 'WORKSPACE_DIR="$HOME/alias/work"' >> "$project/config/profiles.conf"
expect 2 "$cli" repo clone class/one --method gh
expect 0 "$cli" "${clone[@]}" "$tmp/outside/./explicit"
expect 1 "$cli" all --profile secondary --no-passphrase
[[ ! -e $tmp/outside/work ]]
echo 'WORKSPACE_DIR="$HOME/Work Area"' >> "$project/config/profiles.conf"
git -C "$explicit" worktree add -q --detach "$tmp/linked"
expect 0 "$cli" "${clone[@]}" "$tmp/linked/"
: > "$TRACE"
FAULT=query expect 1 "$cli" "${remote[@]}" linked
[[ ! -s $TRACE ]]
FAULT=noadd expect 5 "$cli" "${remote[@]}" linked
expect 0 "$cli" "${remote[@]}" linked
expect 0 "$cli" "${remote[@]}" linked
[[ $(cat "$TRACE") == $'add\nadd' && $(git -C "$explicit" config remote.backup.url) == https://github.com/class/one.git ]]
git init -q "$tmp/super"
git -C "$tmp/super" -c protocol.file.allow=always submodule add -q "$tmp/remotes/one.git" child
expect 0 "$cli" "${remote[@]}" "$tmp/super/child"
cp "$explicit/.git/config" "$tmp/explicit-config"
expect 1 "$cli" repo remote class/two --repo linked --name backup --method gh
mkdir "$explicit/sub" "$tmp/fake"
printf 'gitdir: %s\n' "$explicit/.git" > "$tmp/fake/.git"
expect 2 "$cli" "${remote[@]}" fake
ln -s "$explicit/.git/config" "$tmp/fake/linked-config"
git init -q "$tmp/unsafe"
mv "$tmp/unsafe/.git/config" "$tmp/unsafe-original"
ln -s "$tmp/fake/linked-config" "$tmp/unsafe/.git/config"
expect 2 "$cli" "${remote[@]}" "$tmp/unsafe"
expect 2 "$cli" "${remote[@]}" "$explicit/sub"
GIT_DIR="$explicit/.git" expect 2 "$cli" "${remote[@]}" linked
GIT_WORK_TREE="$tmp/linked" expect 2 "$cli" "${clone[@]}" "$tmp/new"
GIT_INDEX_FILE="$tmp/index" expect 2 "$cli" "${clone[@]}" "$tmp/new"
ln -s "$tmp/outside" "$tmp/link"
ln -s "$tmp/not-created" "$tmp/dangling"
for path in "$tmp/link/new" "$tmp/link/../new" "$tmp/dangling" "$HOME/./" "$workspace//" missing "$tmp/missing/child"; do
  expect 2 "$cli" "${clone[@]}" "$path"
done
expect 2 "$cli" "${remote[@]}" "$tmp/link/explicit"
cmp "$tmp/explicit-config" "$explicit/.git/config"
[[ ! -e $tmp/outside/new && ! -e $tmp/not-created && ! -e $tmp/index ]]
# A partial clone or a completed clone with an invalid origin stays unpublished.
for fault in partial wrong; do
  code=1
  [[ $fault != wrong ]] || code=5
  FAULT=$fault expect "$code" "$cli" "${clone[@]}" "$tmp/outside/retry"
  [[ ! -e $tmp/outside/retry ]]
  if compgen -G "$tmp/outside/.dev-bootstrap-clone.*" >/dev/null; then exit 1; fi
done
expect 0 "$cli" "${clone[@]}" "$tmp/outside/retry"
# On retry, a list resumes from already verified clones.
WORKSPACE_DIR="$HOME/Retry"
repository_method=gh
printf 'class/two\nclass/one\n' > "$list"
: > "$TRACE"
FAULT=second expect 1 runner_run repository
[[ -d $WORKSPACE_DIR/one/.git && ! -e $WORKSPACE_DIR/two && $(cat "$TRACE") == $'clone\nclone' ]]
: > "$TRACE"
expect 0 runner_run repository
[[ -d $WORKSPACE_DIR/two/.git && $(cat "$TRACE") == clone ]]
# Independently fail the Runner's final verification after a real local clone.
printf 'class/one\n' > "$list"
WORKSPACE_DIR="$HOME/Verify"
repository_method=gh
repository_postcheck() { repository_check && return 19; return 1; }
REGISTRY_VERIFY[index]=repository_postcheck
expect 1 runner_run repository
grep -Fq 'verify returned 19' "$tmp/output"
[[ -d $WORKSPACE_DIR/one/.git ]]
echo 'PASS: Repository manifest, read-only checks, local clones, worktrees, recovery and legacy commands'
