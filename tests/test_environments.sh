#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
project="$tmp/project"
mkdir -p "$HOME" "$project"
cp -R "$root"/{setup.sh,bootstrap.sh,lib,core,modules,config} "$project/"
source "$project/lib/logger.sh"
source "$project/lib/config.sh"
source "$project/core/registry.sh"
source "$project/modules/workspace.sh"
source "$project/modules/iterm.sh"
discover_modules "$project"

defaults="$project/config/defaults.conf"
minimal="$project/config/environments/minimal.conf"
profile="$project/config/profiles.conf"
cli="$project/bootstrap.sh"
expect_error() {
  local rc=0
  "$@" > "$tmp/out" 2>&1 || rc=$?
  [[ $rc == 2 ]] || { echo "Expected configuration/usage error, got $rc" >&2; return 1; }
}

printf '%s\n' 'INSTALL_NODE=false' 'INSTALL_PYTHON=false' 'INSTALL_ITERM=true' >> "$defaults"
printf '%s\n' 'INSTALL_ITERM=false' 'INSTALL_PYTHON=true' 'DEFAULT_GITHUB_PROFILE=secondary' > "$profile"
load_config "$project"
[[ $ENVIRONMENT == classroom && $DEFAULT_GITHUB_PROFILE == secondary ]]
[[ ${ENABLED_MODULES[*]} == 'workspace git github shell python repository' ]]
# Old installations may have no classroom file. An explicit list in that file
# takes priority over the same legacy flags, even when given in profiles.conf.
classroom="$project/config/environments/classroom.conf"
mv "$classroom" "$tmp/classroom"
load_config "$project" classroom
[[ ${ENABLED_MODULES[*]} == 'workspace git github shell python repository' ]]
printf 'ENABLED_MODULES=(iterm node)\n' > "$classroom"
load_config "$project" classroom
[[ ${ENABLED_MODULES[*]} == 'iterm node' ]]
mv "$tmp/classroom" "$classroom"
load_config "$project" minimal
[[ $ENVIRONMENT == minimal && $DEFAULT_GITHUB_PROFILE == secondary ]]
[[ ${ENABLED_MODULES[*]} == 'workspace git github shell' ]]

# Check all three overlays, a configured default environment, and selecting the
# other environment explicitly. The selected file can also override scalars.
printf '%s\n' 'DEFAULT_ENVIRONMENT=minimal' 'NODE_VERSION=20' 'ENABLED_MODULES=(iterm)' >> "$defaults"
printf 'NODE_VERSION=21\n' >> "$minimal"
load_config "$project"
[[ $ENVIRONMENT == minimal && $NODE_VERSION == 21 && ${ENABLED_MODULES[*]} == 'workspace git github shell' ]]
load_config "$project" classroom
[[ $ENVIRONMENT == classroom && $NODE_VERSION == 20 && ${ENABLED_MODULES[*]} == iterm ]]
cat >> "$profile" <<'CONF'
NODE_VERSION=22
ENABLED_MODULES=(python node)
CONF
load_config "$project"
[[ $NODE_VERSION == 22 && ${ENABLED_MODULES[*]} == 'python node' ]]
printf 'ENABLED_MODULES=()\n' >> "$profile"
load_config "$project" classroom
[[ ${#ENABLED_MODULES[@]} == 0 ]]
declare -p ENABLED_MODULES >/dev/null
mv "$profile" "$tmp/overrides"
load_config "$project" minimal
[[ $NODE_VERSION == 21 && ${ENABLED_MODULES[*]} == 'workspace git github shell' ]]
keys=("${REGISTRY_COMMON_KEYS[@]}" WORKSPACE_DIR NODE_VERSION PYTHON_INSTALL_METHOD PYTHON_VERSION ENABLED_MODULES)
declare -p "${keys[@]}" > "$tmp/before"
unchanged() { declare -p "${keys[@]}" > "$tmp/after"; cmp "$tmp/before" "$tmp/after"; }
for bad in 'unset ENABLED_MODULES' 'unset ENABLED_MODULES; ENABLED_MODULES=git' \
    'ENABLED_MODULES=(git missing)' 'ENABLED_MODULES=(git git)' 'ENABLED_MODULES=("")' \
    'ENABLED_MODULES=("git shell")' 'ENABLED_MODULES=([0]=git [2]=shell)' \
    'ENABLED_MODULES=(node); NODE_VERSION=bad' 'return 9'; do
  printf '%s\n' 'NODE_VERSION=19' "$bad" > "$profile"
  expect_error load_config "$project" minimal
  unchanged
done
if (( BASH_VERSINFO[0] >= 4 )); then
  printf '%s\n' 'unset ENABLED_MODULES; declare -A ENABLED_MODULES=([a]=git)' > "$profile"
  expect_error load_config "$project" minimal
  unchanged
fi
printf 'NODE_VERSION=bad\nENABLED_MODULES=()\n' > "$profile"
expect_error load_config "$project" classroom
unchanged
rm "$profile"
# An absent array cannot masquerade as the zero-count record of an explicit ().
( unset ENABLED_MODULES; expect_error config_write_snapshot ENABLED_MODULES )
(
  readonly -a ENABLED_MODULES
  printf '%s\0' NODE_VERSION scalar 19 ENABLED_MODULES array 0 > "$tmp/wire"
  expect_error config_apply_snapshot NODE_VERSION ENABLED_MODULES < "$tmp/wire"
  [[ $NODE_VERSION == 21 && ${ENABLED_MODULES[*]} == 'workspace git github shell' ]]
)
mv "$minimal" "$tmp/minimal"
expect_error load_config "$project" minimal
unchanged
mv "$tmp/minimal" "$minimal"
expect_error load_config "$project" '../minimal'
unchanged

# Every malformed array frame follows a valid, changed scalar. Neither field
# may be published. A zero count is valid only if it has no trailing data.
for payload in 'scalar|git|' 'array|1|' 'array|2|git|shell' \
    'array|0|git|' 'array|2|git|git|' 'array|1|missing|' \
    'array|01|git|' 'array|-1|' 'array|x[$(touch "$HOME/unexpected")]|'; do
  printf '%s\0' NODE_VERSION scalar 19 ENABLED_MODULES > "$tmp/wire"
  printf '%s' "$payload" | tr '|' '\000' >> "$tmp/wire"
  expect_error config_apply_snapshot NODE_VERSION ENABLED_MODULES < "$tmp/wire"
  unchanged
done

# Record dispatch and arguments at the Runner boundary. Invalid requests
# must be rejected before dispatch or any manifest read.
export TRACE="$tmp/trace"
cat >> "$project/core/cli.sh" <<'HOOKS'
repository_read_list() { echo manifest >> "$TRACE"; }
runner_run() {
  RUNNER_STATUS=SKIPPED RUNNER_PHASE=check RUNNER_REASON=ready
  case $1 in
    git) echo "git $identity_profile" ;;
    github) echo "github $github_profile $github_method" ;;
    iterm|node) echo "$1 $node_request" ;;
    *) echo "$1" ;;
  esac >> "$TRACE"
}
HOOKS
printf '%s\n' 'DEFAULT_AUTH_METHOD=gh' 'DEFAULT_GITHUB_PROFILE=secondary' > "$profile"
: > "$TRACE"
"$cli" all --method ssh --environment minimal --profile personal >/dev/null
[[ $(cat "$TRACE") == $'workspace\ngit personal\ngithub personal ssh\nshell' ]]
: > "$TRACE"
"$cli" --environment classroom all --profile personal >/dev/null
[[ $(cat "$TRACE") == 'iterm 20' ]]
: > "$TRACE"
printf 'ENABLED_MODULES=(shell node)\n' >> "$profile"
printf '10\n0\n' | "$cli" --environment classroom >/dev/null
[[ $(cat "$TRACE") == $'shell\nnode 20' ]]
: > "$TRACE"
printf 'ENABLED_MODULES=()\n' >> "$profile"
"$cli" all >/dev/null
[[ ! -s $TRACE ]]
printf 'ENABLED_MODULES=(git missing)\n' >> "$profile"
expect_error "$cli" all
printf '%s\n' 'touch "$HOME/config-was-read"' > "$profile"
expect_error "$cli" all --environment '../../x'
expect_error "$cli" --environment ''
expect_error "$cli" all --environment
expect_error "$cli" --environment minimal all --environment classroom
[[ ! -s $TRACE && -z $(ls -A "$HOME") ]]
echo 'PASS: environment selection, CLI/menu precedence, legacy conversion and atomic array snapshots'
