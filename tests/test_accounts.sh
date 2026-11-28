#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/project"
bash "$root/tests/copy-project.sh" "$root" "$tmp/project"
project=$tmp/project
source "$project/lib/logger.sh"
source "$project/lib/config.sh"
source "$project/lib/profiles.sh"
source "$project/core/registry.sh"
source "$project/modules/workspace.sh"
source "$project/modules/iterm.sh"
discover_modules "$project"
accounts=$project/config/accounts.conf
profiles=$project/config/profiles.conf
cat > "$profiles" <<'CONF'
GITHUB_PERSONAL_USER=legacy
GITHUB_PERSONAL_EMAIL=legacy@example.com
NODE_VERSION=20
ENABLED_MODULES=(git shell)
CONF
load_config "$project"
profile_load personal
[[ $PROFILE_USER == legacy && $PROFILE_EMAIL == legacy@example.com ]]
cat > "$accounts" <<'CONF'
GITHUB_PERSONAL_USER=new
GITHUB_PERSONAL_EMAIL=""
GITHUB_SECONDARY_USER='invalid user'
NODE_VERSION=invalid
DEFAULT_GITHUB_PROFILE=secondary
ENVIRONMENT=minimal
ENABLED_MODULES=(missing)
CONF
load_config "$project"
[[ $GITHUB_PERSONAL_USER == new && $GITHUB_PERSONAL_EMAIL == '' ]]
[[ $NODE_VERSION == 20 && $DEFAULT_GITHUB_PROFILE == personal && $ENVIRONMENT == classroom ]]
[[ ${ENABLED_MODULES[*]} == 'git shell' ]]
rc=0; profile_load personal 2>"$tmp/error" || rc=$?
[[ $rc == 2 ]]
grep -Fq config/accounts.conf "$tmp/error"
printf '%s\n' 'GITHUB_SECONDARY_USER="invalid user"' 'GITHUB_SECONDARY_EMAIL=s@example.com' 'unset GITHUB_PERSONAL_EMAIL' > "$accounts"
load_config "$project"
profile_load personal
[[ $PROFILE_USER == legacy && $PROFILE_EMAIL == legacy@example.com ]]
rc=0; profile_load secondary 2>/dev/null || rc=$?
[[ $rc == 2 ]]
keys=("${REGISTRY_COMMON_KEYS[@]}" NODE_VERSION WORKSPACE_DIR PYTHON_VERSION PYTHON_INSTALL_METHOD ENABLED_MODULES)
declare -p "${keys[@]}" > "$tmp/good"
printf '%s\n' 'NODE_VERSION=21' 'ENABLED_MODULES=()' >> "$profiles"
for fault in 'return 1' 'GITHUB_PERSONAL_EMAIL=(bad)' 'exit 0'; do
  printf '%s\n' 'GITHUB_PERSONAL_USER=partial' "$fault" > "$accounts"
  rc=0; load_config "$project" 2>/dev/null || rc=$?
  [[ $rc == 2 ]]
  declare -p "${keys[@]}" > "$tmp/after"
  cmp "$tmp/good" "$tmp/after"
done
rm "$profiles"
printf 'GITHUB_PERSONAL_USER=only\n' > "$accounts"
load_config "$project"
[[ $GITHUB_PERSONAL_USER == only && -z $GITHUB_PERSONAL_EMAIL && -z $GITHUB_SECONDARY_USER ]]
echo 'PASS: account overlays, empty and removed fields, selection-time validation and atomic reload'
