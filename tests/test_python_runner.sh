#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces" FIXTURE="$tmp/fixture" PATH="$tmp/bin:$PATH"
mkdir -p "$HOME" "$FIXTURE" "$tmp/bin"
cat > "$FIXTURE/uv" <<'MOCK'
#!/usr/bin/env bash
set -eu
[[ $1 == python ]]
case $2 in
  find)
    # Any omitted flag would allow the wrong interpreter, downloads or cache writes.
    [[ "${*:4}" == '--managed-python --system --no-project --no-python-downloads --no-cache --offline --color never --show-version' ]] || exit 77
    case ${FAULT:-} in
      lookup) echo 'error: interpreter query failed' >&2; exit 2 ;;
      garbage) echo /unexpected/python; exit 0 ;;
      wrong) echo 3.11.1; exit 0 ;;
    esac
    if [[ -f "$FIXTURE/installed" ]]; then
      found=$(cat "$FIXTURE/installed")
      if [[ $found == "$3" || $found == "$3".* ]]; then echo "$found"; exit 0; fi
    fi
    echo "error: No interpreter found for Python $3 in managed installations" >&2; exit 2 ;;
  install)
    echo "install $3" >> "$FIXTURE/writes"
    case ${FAULT:-} in install) exit 31 ;; lost-install) exit 0 ;; esac
    case $3 in 3|3.12) echo 3.12.7 ;; *) echo "$3" ;; esac > "$FIXTURE/installed" ;;
  *) exit 1 ;;
esac
MOCK
cat > "$tmp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -eu
[[ $# == 9 && "${*:1:6}" == '--fail --location --show-error --silent --retry 2' && $8 == -o ]]
case $7 in
  https://astral.sh/uv/install.sh)
    echo bootstrap >> "$FIXTURE/writes"
    cat > "$9" <<'INSTALL'
set -eu
test "$UV_NO_MODIFY_PATH" = 1
mkdir -p "$HOME/.local/bin"
cp "$FIXTURE/uv" "$HOME/.local/bin/uv"
INSTALL
    ;;
  https://www.python.org/ftp/python/3.12.7/Python-3.12.7.tgz)
    echo download >> "$FIXTURE/writes"; echo archive > "$9" ;;
  *) exit 1 ;;
esac
MOCK
cat > "$tmp/bin/tar" <<'MOCK'
#!/usr/bin/env bash
set -eu
[[ $1 == -xzf && -s $2 && $3 == -C ]]
mkdir "$4/Python-3.12.7"
printf '#!/bin/sh\nprintf "%%s\\n" "${1#--prefix=}" > prefix\n' > "$4/Python-3.12.7/configure"
chmod +x "$4/Python-3.12.7/configure"
MOCK
cat > "$tmp/bin/make" <<'MOCK'
#!/usr/bin/env bash
set -eu
case $1 in
  -j) [[ $2 =~ ^[1-9][0-9]*$ ]]; echo build >> "$FIXTURE/writes" ;;
  install)
    echo publish-stage >> "$FIXTURE/writes"
    [[ $2 == DESTDIR=/* ]]
    prefix=$(cat prefix)
    [[ $prefix == "$HOME/.local/python-3.12.7" ]]
    dir="${2#DESTDIR=}$prefix"
    mkdir -p "$dir/bin"
    echo partial > "$dir/incomplete"
    [[ ${FAULT:-} != partial ]] || exit 33
    rm "$dir/incomplete"
    cp "$FIXTURE/interpreter" "$dir/bin/python3.12"
    ;;
  *) exit 1 ;;
esac
MOCK
cat > "$FIXTURE/interpreter" <<'MOCK'
#!/usr/bin/env bash
set -eu
[[ $# == 7 && "${*:1:5}" == '-E -s -S -B -c' && $6 == *sys.version_info* && -d "$7/bin" ]]
case ${FAULT:-} in
  broken) exit 8 ;;
  wrong) echo 3.12.6 ;;
  final-only) [[ "$7" != "$HOME/.local/python-3.12.7" ]] || exit 9; echo 3.12.7 ;;
  *) echo 3.12.7 ;;
esac
MOCK
chmod +x "$tmp/bin/"* "$FIXTURE/uv" "$FIXTURE/interpreter"
run_python() {
  local wanted=$1 message=$2 writes=$3 rc=0
  shift 3
  : > "$FIXTURE/writes"
  "$root/bootstrap.sh" install python "$@" > "$tmp/out" 2>&1 || rc=$?
  if [[ $rc != "$wanted" || $(paste -sd, "$FIXTURE/writes") != "$writes" ]] || ! grep -Fq "$message" "$tmp/out"; then
    cat "$tmp/out" "$FIXTURE/writes" >&2
    echo "Expected $wanted, $message, [$writes]; got $rc" >&2; return 1
  fi
}

source_args=(--method source --version 3.12.7)
prefix="$HOME/.local/python-3.12.7"
run_python 2 'Source build requires full X.Y.Z' '' --method source --version 3.12
[[ ! -e "$HOME/.local" && ! -e "$HOME/.zshrc" ]]
# A Shell conflict is irrelevant for source builds.
echo '# Dev Bootstrap managed environment (edited)' > "$HOME/.zshrc"
FAULT=partial run_python 1 'apply returned 1' 'download,build,publish-stage' "${source_args[@]}"
[[ -z $(ls -A "$HOME/.local") ]]
FAULT=wrong run_python 5 'apply returned 5' 'download,build,publish-stage' "${source_args[@]}"
[[ ! -e $prefix ]]
run_python 0 'python: SUCCESS' 'download,build,publish-stage' "${source_args[@]}"
run_python 0 'python: SKIPPED' '' "${source_args[@]}"
# Break the live check between apply and verify using a fresh staged install.
mv "$prefix" "$tmp/good"
FAULT=final-only run_python 5 'verify returned 1' 'download,build,publish-stage' "${source_args[@]}"
run_python 0 'python: SKIPPED' '' "${source_args[@]}"
mv "$prefix/bin" "$tmp/bin-saved"
ln -s "$tmp/bin-saved" "$prefix/bin"
run_python 1 'check returned 1' '' "${source_args[@]}"
rm "$prefix/bin"
mv "$tmp/bin-saved" "$prefix/bin"
FAULT=wrong run_python 1 'check returned 1' '' "${source_args[@]}"
FAULT=broken run_python 1 'check returned 1' '' "${source_args[@]}"
[[ ! -e "$HOME/.config" && $(cat "$HOME/.zshrc") == '# Dev Bootstrap managed environment (edited)' ]]
mv "$prefix" "$tmp/saved"
ln -s "$tmp/saved" "$prefix"
run_python 1 'check returned 1' '' "${source_args[@]}"
[[ -L $prefix ]]
rm "$prefix"
mkdir "$prefix"
echo keep > "$prefix/notes"
run_python 1 'check returned 1' '' "${source_args[@]}"
[[ $(cat "$prefix/notes") == keep ]]

run_python 1 'python: NEEDS_ACTION' ''
rm "$HOME/.zshrc"
# Neither a virtualenv nor an interpreter in PATH satisfies this request.
export VIRTUAL_ENV="$tmp/venv"
mkdir -p "$VIRTUAL_ENV/bin"
for name in python python3; do
  printf '#!/bin/sh\necho external-python >> "$FIXTURE/writes"\nexit 1\n' > "$tmp/bin/$name"
  chmod +x "$tmp/bin/$name"
  ln -s "$tmp/bin/$name" "$VIRTUAL_ENV/bin/$name"
done
run_python 0 'python: SUCCESS' 'bootstrap,install 3.12'
run_python 0 'python: SKIPPED' '' --version 3
run_python 0 'python: SKIPPED' '' --version 3.12.7
rm "$HOME/.config/dev-bootstrap/env.zsh"
run_python 0 'python: SUCCESS' ''
mv "$HOME/.config/dev-bootstrap/env.zsh" "$tmp/env.zsh"
ln -s "$tmp/env.zsh" "$HOME/.config/dev-bootstrap/env.zsh"
run_python 1 'check returned 1' '' --version 3.12.8
rm "$HOME/.config/dev-bootstrap/env.zsh"
FAULT=lost-install run_python 5 'apply returned 5' 'install 3.12.8' --version 3.12.8
[[ ! -e "$HOME/.config/dev-bootstrap/env.zsh" ]]
mv "$tmp/env.zsh" "$HOME/.config/dev-bootstrap/env.zsh"
for fault in lookup garbage wrong; do
  FAULT=$fault run_python 1 'check returned 1' ''
done
FAULT=install run_python 1 'apply returned 1' 'install 3.12.8' --version 3.12.8
FAULT=lost-install run_python 5 'verify returned 10' 'install 3.12.8' --version 3.12.8
run_python 0 'python: SUCCESS' 'install 3.12.8' --version 3.12.8
printf '6\n0\n' | "$root/setup.sh" > "$tmp/menu"
grep -Fq 'python: SKIPPED' "$tmp/menu"
# Force unavailable build tools without depending on the host's installed tools.
mkdir "$tmp/project"
cp -R "$root"/{setup.sh,bootstrap.sh,core,modules,lib,config} "$tmp/project/"
printf '\nrequire_command() { [[ $1 != make ]]; }\n' >> "$tmp/project/lib/common.sh"
root="$tmp/project"
run_python 3 'python: BLOCKED' '' --version 3.12.8 --method source
echo 'PASS: uv managed discovery, Shell repair, source isolation, staged build, retry and exit codes'
