#!/usr/bin/env bash
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" TRACE="$tmp/trace"
mkdir "$HOME"
echo keep > "$HOME/file"
cp -R "$root"/{setup.sh,bootstrap.sh,core,lib,modules,config} "$tmp/"
mkdir "$tmp/modules/sample"
entry="$tmp/modules/sample/module.sh"
cat > "$entry" <<'MODULE'
sample_check() { echo check >> "$TRACE"; }
sample_command() { printf '%s\0' "$@" > "$TRACE"; return 4; }
register_module --id sample --name 'Sample tool' --platforms 'Darwin Linux' --check sample_check --apply sample_check --verify sample_check
register_command 'sample inspect' sample_command '[ARG ...]'
MODULE
cli="$tmp/setup.sh"
"$cli" list > "$tmp/list"
"$cli" help > "$tmp/help"
printf '0\n' | "$cli" > "$tmp/menu"
for view in list help; do grep -Fxq 'sample  Sample tool' "$tmp/$view"; done
grep -Fq 'sample inspect [ARG ...]' "$tmp/help"
grep -Fxq '13. Apply sample (Sample tool)' "$tmp/menu"
while IFS= read -r row; do grep -Fxq "$row" "$tmp/menu"; done <<'MENU'
1. Check environment
2. Configure Git identity
3. Configure GitHub (SSH default)
4. Verify GitHub authentication
5. Install Node.js
6. Install Python
7. Install iTerm2
8. Configure zsh
9. Configure Workspace
10. Run all
11. Help
0. Exit
MENU
[[ ! -e $TRACE ]]
printf '13\n0\n' | "$cli" > "$tmp/menu"
[[ $(cat "$TRACE") == check ]]
args=('a b' '' '*' '--flag' '$(false)')
rc=0
"$cli" sample inspect "${args[@]}" || rc=$?
[[ $rc == 4 ]]
printf '%s\0' "${args[@]}" > "$tmp/expected"
cmp "$tmp/expected" "$TRACE"
echo "register_command 'repo clone' sample_command ''" >> "$entry"
rc=0
"$cli" list > "$tmp/out" 2>&1 || rc=$?
[[ $rc == 2 && $(ls -A "$HOME") == file && $(cat "$HOME/file") == keep ]]
echo 'PASS: registry views, legacy slots, ordered extension slots and literal command arguments'
