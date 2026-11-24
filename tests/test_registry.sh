#!/usr/bin/env bash
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir "$HOME" "$tmp/project"
cp -R "$root"/{setup.sh,bootstrap.sh,core,lib,modules,config} "$tmp/project/"
project="$tmp/project"
source "$project/lib/logger.sh"
source "$project/modules/workspace.sh"
source "$project/modules/iterm.sh"
source "$project/core/registry.sh"

discover_modules "$project"
index=$(registry_index workspace)
[[ ${REGISTRY_NAMES[index]} == Workspace && ${REGISTRY_APPLY[index]} == workspace_configure ]]
if registry_index absent; then exit 1; fi
WORKSPACE_DIR="$HOME/Documents"
status=0
"${REGISTRY_CHECK[index]}" || status=$?
[[ $status == 10 && ! -e $WORKSPACE_DIR ]]
mkdir "$WORKSPACE_DIR"
"${REGISTRY_VERIFY[index]}"
rmdir "$WORKSPACE_DIR"
touch "$WORKSPACE_DIR"
status=0
workspace_status || status=$?
[[ $status == 2 ]]
rm "$WORKSPACE_DIR"

fixture="$project/modules/sample"
mkdir "$fixture"
entry="$fixture/module.sh"
valid='register_module --id sample --name Sample --platforms Linux --check sample_ok --apply sample_ok --verify sample_ok'
write_module() {
  printf '%s\n' 'sample_ok() { return 0; }' "$@" > "$entry"
}
reject() {
  local script
  for script in setup.sh bootstrap.sh; do
    if "$project/$script" configure workspace >"$tmp/out" 2>&1; then
      echo "Unexpected success: $1 ($script)" >&2; exit 1
    fi
    grep -Fq -- "$1" "$tmp/out"
    [[ -z "$(ls -A "$HOME")" ]]
  done
}

write_module "$valid --depends workspace"
discover_modules "$project"
index=$(registry_index sample)
[[ ${REGISTRY_DEPENDS[index]} == workspace ]]
write_module "$valid" "$valid" ':'
reject 'Duplicate module ID'
write_module ':'
reject 'Expected one valid registration'
write_module "${valid/--id sample/--id Bad}"
reject 'Invalid module ID'
write_module "${valid/--id sample/--id other}"
reject 'Invalid module ID'
write_module "${valid% --verify*}"
reject 'Invalid verify hook'
write_module "${valid/--apply sample_ok/--apply sample_missing}"
reject 'Invalid apply hook'
write_module "$valid" 'return 1'
reject 'Module load failed'
write_module "$valid --depends missing"
reject 'unknown dependency'
write_module "${valid/Linux/Plan9}"
reject 'Unknown platform'
write_module "$valid --unknown x"
reject 'Unknown module option'
write_module "$valid --keys SAMPLE_VERSION"
reject 'Incomplete configuration hooks'
write_module "$valid --keys 'SAMPLE_X SAMPLE_X' --defaults sample_ok --validate sample_ok"
reject 'Duplicate keys'
mv "$entry" "$tmp/outside.sh"
ln -s "$tmp/outside.sh" "$entry"
reject 'Unsafe module entry'
rm "$entry"
mv "$fixture" "$tmp/outside"
mv "$tmp/outside.sh" "$tmp/outside/module.sh"
ln -s "$tmp/outside" "$fixture"
reject 'Unsafe module entry'
echo 'PASS: registry lookup, workspace contract, invalid registrations and links before dispatch'
