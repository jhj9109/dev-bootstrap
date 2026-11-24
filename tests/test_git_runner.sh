#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$tmp/project" "$tmp/bin" "$tmp/ordinary"
cp -R "$root"/{setup.sh,bootstrap.sh,lib,core,modules,config} "$tmp/project/"
cat > "$tmp/project/config/profiles.conf" <<'CONF'
GITHUB_PERSONAL_USER=alice
GITHUB_PERSONAL_EMAIL=alice@example.com
GITHUB_SECONDARY_USER=bob
GITHUB_SECONDARY_EMAIL=bob@example.com
CONF
REAL_GIT=$(command -v git)
export REAL_GIT
export WRITE_LOG="$tmp/writes"
git init -q "$tmp/main"
git -C "$tmp/main" -c user.name=fixture -c user.email=fixture@example.com commit -qm base --allow-empty
repo="$tmp/linked tree"
git -C "$tmp/main" worktree add -q --detach "$repo"
git init -q --bare "$tmp/bare"
git config --global custom.keep global
git -C "$repo" config --local custom.keep local

cat > "$tmp/bin/git" <<'MOCK'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    --get-all)
      if [[ ${GIT_FIXTURE:-} == read-error && ${!#} == user.email ]]; then exit 23; fi ;;
    --replace-all)
      echo write >> "$WRITE_LOG"
      case "${GIT_FIXTURE:-}" in
        write-error) [[ "${!#}" != *@* ]] || exit 8 ;;
        lost-write) exit 0 ;;
      esac ;;
  esac
done
exec "$REAL_GIT" "$@"
MOCK
chmod +x "$tmp/bin/git"
export PATH="$tmp/bin:$PATH"
expect_cli() {
  local want=$1 message=$2 rc=0
  shift 2
  : > "$WRITE_LOG"
  "$tmp/project/bootstrap.sh" configure git "$@" > "$tmp/out" 2>&1 || rc=$?
  if [[ $rc != "$want" ]] || ! grep -Fq "$message" "$tmp/out"; then
    cat "$tmp/out" >&2
    echo "Expected $want ($message), got $rc" >&2
    return 1
  fi
}

for scope in global local; do
  if [[ $scope == global ]]; then
    options=(--global --profile personal)
    config=(config --global)
    name=alice email=alice@example.com
  else
    options=(--repo "$repo" --profile secondary)
    config=(-C "$repo" config --local)
    name=bob email=bob@example.com
  fi
  # Missing first key must not hide a failure to read the second key.
  GIT_FIXTURE=read-error expect_cli 1 'check returned 1' "${options[@]}"
  [[ ! -s $WRITE_LOG ]]
  GIT_FIXTURE=write-error expect_cli 1 'apply returned 1' "${options[@]}"
  GIT_FIXTURE=lost-write expect_cli 5 'verify returned 10' "${options[@]}"
  expect_cli 0 'git: SUCCESS' "${options[@]}"
  expect_cli 0 'git: SKIPPED' "${options[@]}"
  [[ ! -s $WRITE_LOG ]]
  git "${config[@]}" user.email wrong@example.com
  expect_cli 0 'git: SUCCESS' "${options[@]}"
  [[ $(git "${config[@]}" user.name) == "$name" && $(git "${config[@]}" user.email) == "$email" ]]
  [[ $(git config --global custom.keep) == global && $(git -C "$repo" config --local custom.keep) == local ]]
done
[[ $(git config --global user.name) == alice && $(git config --global user.email) == alice@example.com ]]
git config --global user.email changed@example.com
expect_cli 0 'git: SUCCESS' --global
[[ $(git -C "$repo" config --local user.email) == bob@example.com ]]

for path in "$tmp/bare" "$tmp/main/.git" "$tmp/ordinary" "$tmp/missing"; do
  expect_cli 2 'check returned 2' --repo "$path"
  [[ ! -s $WRITE_LOG ]]
done
GIT_DIR="$tmp/main/.git" expect_cli 2 'check returned 2' --repo "$tmp/ordinary"
[[ ! -s $WRITE_LOG ]]
expect_cli 2 'Conflicting Git scopes' --global --repo "$repo"
[[ ! -s $WRITE_LOG ]]
expect_cli 2 'Conflicting Git scopes' --repo "$repo" --global
[[ ! -s $WRITE_LOG ]]
mkdir "$tmp/config-dir"
GIT_CONFIG_GLOBAL="$tmp/config-dir" expect_cli 1 'check returned 1' --global
[[ ! -s $WRITE_LOG ]]
echo 'require_command() { return 1; }' >> "$tmp/project/lib/common.sh"
expect_cli 3 'git: BLOCKED' --global
[[ ! -s $WRITE_LOG ]]
echo 'PASS: Git author scopes, linked worktree, skipped writes, invalid contexts and hook failures'
