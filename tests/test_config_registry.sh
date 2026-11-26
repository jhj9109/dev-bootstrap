#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
project="$tmp/project"
export HOME="$tmp/home"
mkdir -p "$HOME" "$project"
cp -R "$root"/{setup.sh,bootstrap.sh,lib,core,modules,config} "$project/"
mkdir "$project/modules/sample"
cat > "$project/modules/sample/module.sh" <<'MODULE'
sample_defaults() {
  [[ ! ${SAMPLE_TEXT+x} ]] || return 8
  SAMPLE_TEXT='from module'
  if [[ ${fixture_mode:-} != missing ]]; then SAMPLE_EMPTY=''; fi
  # Only owned keys may escape, even when a hook accidentally writes elsewhere.
  NODE_VERSION=changed
  [[ ${fixture_mode:-} != defaults ]] || return 7
}
sample_validate() {
  [[ $SAMPLE_TEXT != invalid && $NODE_VERSION == 24 ]] || return 2
  [[ ${fixture_mode:-} != validate ]] || return 9
  SAMPLE_TEXT='changed by validator'
  WORKSPACE_DIR=changed
  printf 'fixture hook output\n'
}
sample_ok() { return 0; }
register_module --id sample --name Sample --platforms Linux \
  --keys 'SAMPLE_TEXT SAMPLE_EMPTY' --defaults sample_defaults --validate sample_validate \
  --check sample_ok --apply sample_ok --verify sample_ok
MODULE
source "$project/lib/logger.sh"
source "$project/lib/config.sh"
source "$project/core/registry.sh"
source "$project/modules/workspace.sh"
source "$project/modules/iterm.sh"
discover_modules "$project"

defaults="$project/config/defaults.conf"
profile="$project/config/profiles.conf"
# Exercise the module fallback even when a previous load or the environment
# supplied values. Keep a full legacy defaults.conf for the override test.
cp "$defaults" "$tmp/legacy"
sed -E '/^(NODE_VERSION|PYTHON_VERSION|PYTHON_INSTALL_METHOD|WORKSPACE_DIR)=/d' "$tmp/legacy" > "$defaults"
export SAMPLE_TEXT=ambient
NODE_VERSION=stale
load_config "$project"
[[ $SAMPLE_TEXT == 'from module' && $SAMPLE_EMPTY == '' ]]
[[ $NODE_VERSION == 24 && $PYTHON_VERSION == 3.12 && $PYTHON_INSTALL_METHOD == uv && $WORKSPACE_DIR == "$HOME/Documents" ]]

cp "$tmp/legacy" "$defaults"
printf '%s\n' 'SAMPLE_TEXT="from file"' 'SAMPLE_EMPTY=" "' >> "$defaults"
load_config "$project"
[[ $SAMPLE_TEXT == 'from file' && $SAMPLE_EMPTY == ' ' ]]
cat > "$profile" <<'CONF'
SAMPLE_TEXT=$' \t\n"$(touch "$HOME/unexpected")" \\ * %s\n\n'
SAMPLE_EMPTY=''
WORKSPACE_DIR="$HOME/It Works"
GITHUB_PERSONAL_USER=alice
CONF
load_config "$project"
[[ $SAMPLE_TEXT == $' \t\n"$(touch "$HOME/unexpected")" \\ * %s\n\n' && $SAMPLE_EMPTY == '' ]]
[[ $GITHUB_PERSONAL_USER == alice && $WORKSPACE_DIR == "$HOME/It Works" && ! -e $HOME/unexpected ]]

all_keys=("${REGISTRY_COMMON_KEYS[@]}")
for keys in "${REGISTRY_KEYS[@]}"; do
  [[ -n $keys ]] || continue
  read -r -a owned <<< "$keys"
  all_keys+=("${owned[@]}")
done
all_keys+=(ENABLED_MODULES)
declare -p "${all_keys[@]}" > "$tmp/committed"
reject_load() {
  local rc=0
  load_config "$project" > "$tmp/out" 2>&1 || rc=$?
  [[ $rc == 2 ]] || { echo "Expected configuration error, got $rc" >&2; return 1; }
  declare -p "${all_keys[@]}" > "$tmp/after"
  cmp "$tmp/committed" "$tmp/after"
}
# Change multiple fields before each failure. Compare every committed key.
for bad in 'SAMPLE_TEXT=invalid' 'return 1' 'SAMPLE_TEXT=(one two)' 'unset SAMPLE_EMPTY' \
    'TARGET_OS=other' 'DEFAULT_AUTH_METHOD=other' 'DEFAULT_GITHUB_PROFILE=other' \
    'NODE_VERSION=bad' 'PYTHON_VERSION=bad' 'PYTHON_INSTALL_METHOD=bad' 'WORKSPACE_DIR=""'; do
  printf '%s\n' 'GITHUB_PERSONAL_USER=bob' 'SAMPLE_EMPTY=changed' "$bad" > "$profile"
  reject_load
done
printf '%s\n' 'GITHUB_PERSONAL_USER=bob' > "$profile"
fixture_mode=defaults reject_load
fixture_mode=missing reject_load
fixture_mode=validate reject_load
mv "$defaults" "$tmp/saved"
reject_load
mv "$tmp/saved" "$defaults"

# Exercise the real commit path with corrupt producer output.
(
  config_write_candidate() { cat "$tmp/wire"; }
  ( TARGET_OS=wire; config_write_snapshot "${all_keys[@]}" ) > "$tmp/complete"
  for kind in missing-value partial-value wrong-key duplicate-key extra-field trailing-bytes; do
    case $kind in
      missing-value) printf 'TARGET_OS\0' > "$tmp/wire" ;;
      partial-value) printf 'TARGET_OS\0scalar\0macos' > "$tmp/wire" ;;
      duplicate-key) printf 'TARGET_OS\0scalar\0wire\0TARGET_OS\0scalar\0other\0' > "$tmp/wire" ;;
      wrong-key) printf 'TARGET_OS\0scalar\0wire\0UNREGISTERED_KEY\0scalar\0oops\0' > "$tmp/wire" ;;
      extra-field) cp "$tmp/complete" "$tmp/wire"; printf '\0' >> "$tmp/wire" ;;
      trailing-bytes) cp "$tmp/complete" "$tmp/wire"; printf 'garbage' >> "$tmp/wire" ;;
    esac
    reject_load
  done
)
# The menu reload and CLI startup both use the registered validator.
printf 'SAMPLE_TEXT=invalid\n' > "$profile"
rc=0
"$project/bootstrap.sh" help > "$tmp/out" 2>&1 || rc=$?
[[ $rc == 2 ]]
source "$project/core/menu.sh"
ROOT_DIR=$project
run_workspace() { touch "$tmp/dispatched"; }
menu > "$tmp/out" 2>&1 <<< $'9\n0'
[[ ! -e $tmp/dispatched ]]
grep -Fq 'Configuration reload failed' "$tmp/out"
declare -p "${all_keys[@]}" > "$tmp/after"
cmp "$tmp/committed" "$tmp/after"
printf 'SAMPLE_EMPTY=changed\n' > "$profile"
# An unsuitable destination late in the schema cannot cause a partial commit.
(
  declare -i SAMPLE_EMPTY=1
  declare -p "${all_keys[@]}" > "$tmp/committed"
  reject_load
)
rm "$profile"
load_config "$project"
[[ $SAMPLE_TEXT == 'from file' && $SAMPLE_EMPTY == ' ' && -z $GITHUB_PERSONAL_USER ]]
cat > "$defaults" <<'CONF'
TARGET_OS=macos
DEFAULT_AUTH_METHOD=ssh
DEFAULT_GITHUB_PROFILE=personal
CONF
load_config "$project"
[[ $SAMPLE_TEXT == 'from module' && $SAMPLE_EMPTY == '' && -z $INSTALL_NODE ]]
[[ $WORKSPACE_DIR == "$HOME/Documents" && $NODE_VERSION == 24 ]]
echo 'PASS: registry configuration ownership, precedence, hook isolation and atomic snapshots'
