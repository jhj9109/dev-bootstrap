#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" TEST_STATE="$tmp/state" TEST_BIN="$tmp/bin"
mkdir -p "$HOME" "$TEST_STATE" "$TEST_BIN"
export PATH="$TEST_BIN:$PATH"
# Only the mock installer can publish nvm.sh. Each source must start in a
# fresh hook shell, with the same HOME, working directory and --no-use flag.
export TEST_START="$PWD"
cat > "$TEST_STATE/nvm.sh" <<'NVM'
[[ "${1:-}" == --no-use && $NVM_DIR == "$HOME/.nvm" && $PWD == "$TEST_START" && -z ${NVM_FIXTURE_LOADED:-} ]] || return 41
[[ ${FAULT:-} != load ]] || return 1
NVM_FIXTURE_LOADED=1
cd "$TEST_STATE" || return 1
echo load >> "$TEST_STATE/loads"
nvm() {
  case "$1" in
    version)
      if [[ "$2" == default ]]; then
        case ${FAULT:-} in alias-read) echo N/A; return 22 ;; alias-noise) echo invalid; return 0 ;; esac
        if [[ -f default ]]; then cat default; return; fi
      else
        case ${FAULT:-} in
          query) echo v24.7.3; return 23 ;;
          empty) return 0 ;;
          false-miss) echo N/A; return 0 ;;
          noise) printf 'v24.7.3\nunexpected\n'; return 0 ;;
          wrong) echo v24.70.3; return 0 ;;
        esac
        if [[ -f installed ]]; then
          local found
          found=$(cat installed)
          if [[ $found == "v$2" || $found == "v$2".* ]]; then echo "$found"; return 0; fi
        fi
      fi
      echo N/A; return 3 ;;
    install)
      echo "install $2" >> writes
      [[ ${FAULT:-} != install ]] || return 9
      case "$2" in 24|24.7|24.7.3) echo v24.7.3 ;; *) echo "v$2" ;; esac > installed ;;
    alias)
      [[ $2 == default ]] || return 1
      echo "alias $3" >> writes
      [[ ${FAULT:-} != alias ]] || return 1
      [[ ${FAULT:-} == lost-write ]] || cp installed default ;;
    use) echo "use $2" >> writes ;;
    *) return 99 ;;
  esac
}
NVM
cat > "$TEST_BIN/curl" <<'CURL'
#!/usr/bin/env bash
echo download >> "$TEST_STATE/writes"
[[ $# == 9 && "$1 $2 $3 $4 $5 $6" == '--fail --location --show-error --silent --retry 2' &&
   $7 == https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh && $8 == -o ]] || exit 1
case ${FAULT:-} in
  download) exit 7 ;;
  no-script) printf '#!/bin/sh\nexit 0\n' > "$9"; exit 0 ;;
esac
cat > "$9" <<'INSTALL'
[[ $PROFILE == /dev/null && $NVM_DIR == "$HOME/.nvm" ]] || exit 1
mkdir -p "$NVM_DIR" && cp "$TEST_STATE/nvm.sh" "$NVM_DIR/nvm.sh"
INSTALL
CURL
for cmd in node npm; do
  printf '#!/bin/sh\necho unexpected >> "$TEST_STATE/writes"\nexit 1\n' > "$TEST_BIN/$cmd"
done
chmod +x "$TEST_BIN/"*
run_node() {
  local expected_rc=$1 expected_log=$2 expected_writes=$3 rc=0
  shift 3
  : > "$TEST_STATE/writes"
  : > "$TEST_STATE/loads"
  "$root/bootstrap.sh" install node "$@" > "$tmp/out" 2>&1 || rc=$?
  if [[ $rc != "$expected_rc" || $(paste -sd, "$TEST_STATE/writes") != "$expected_writes" ]] ||
     ! grep -Fq "$expected_log" "$tmp/out"; then
    cat "$tmp/out" "$TEST_STATE/writes" >&2
    echo "Expected exit $expected_rc, $expected_log and [$expected_writes], got exit $rc" >&2
    return 1
  fi
}

FAULT=download run_node 1 'apply returned 1' 'download'
FAULT=no-script run_node 5 'apply returned 5' 'download'
run_node 0 'node: SUCCESS' 'download,install 24,use 24,alias 24'
run_node 0 'node: SKIPPED' ''
[[ $(wc -l < "$TEST_STATE/loads") -eq 1 ]]
run_node 0 'node: SKIPPED' '' --version 24.7
run_node 0 'node: SKIPPED' '' --version 24.7.3
echo v20.0.0 > "$TEST_STATE/default"
run_node 0 'node: SUCCESS' 'alias 24.7' --version 24.7
[[ $(wc -l < "$TEST_STATE/loads") -eq 3 ]]
rm "$HOME/.config/dev-bootstrap/env.zsh"
run_node 0 'node: SUCCESS' ''
[[ -s "$HOME/.config/dev-bootstrap/env.zsh" ]]
for fault in load query empty false-miss noise wrong alias-read alias-noise; do
  FAULT=$fault run_node 1 'check returned 1' '' --version 24.7
done
# A broken alias query is fatal even when the requested version is absent.
FAULT=alias-read run_node 1 'check returned 1' '' --version 24.7.2
FAULT=install run_node 1 'apply returned 1' 'install 24.7.2' --version 24.7.2
run_node 0 'node: SUCCESS' 'install 24.7.2,use 24.7.2,alias 24.7.2' --version 24.7.2
rm "$TEST_STATE/default"
FAULT=alias run_node 1 'apply returned 1' 'alias 24'
FAULT=lost-write run_node 5 'verify returned 10' 'alias 24'
echo '# user edit' >> "$HOME/.config/dev-bootstrap/env.zsh"
run_node 1 'node: NEEDS_ACTION' ''
rm "$HOME/.config/dev-bootstrap/env.zsh"
ln -s "$TEST_STATE/default" "$HOME/.config/dev-bootstrap/env.zsh"
run_node 1 'check returned 1' ''
rm "$HOME/.config/dev-bootstrap/env.zsh"
run_node 0 'node: SUCCESS' 'alias 24'
printf '5\n0\n' | "$root/setup.sh" > "$tmp/menu"
grep -Fq 'node: SKIPPED' "$tmp/menu"

mkdir "$HOME/.nvm/alias"
ln -s "$TEST_STATE/default" "$HOME/.nvm/alias/default"
run_node 1 'check returned 1' ''
rm "$HOME/.nvm/nvm.sh"
echo keep > "$HOME/.nvm/custom"
run_node 1 'check returned 1' ''
[[ $(cat "$HOME/.nvm/custom") == keep ]]
echo 'PASS: Node hook isolation, version resolution, selective repairs, diagnostics and exit codes'
