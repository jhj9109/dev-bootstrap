#!/usr/bin/env bash
set -eu

scripts=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Exercise the same env shebang and nested command lookup used by the suite.
cat > "$tmp/probe" <<'PROBE'
#!/usr/bin/env bash
[[ $BASH_VERSION == "$1" && $BASH -ef "$2" ]] &&
  bash -c '[[ $BASH_VERSION == "$1" && $BASH -ef "$2" ]]' probe "$1" "$2"
PROBE
chmod +x "$tmp/probe"

run_row() (
  label=$1
  binary=$2
  case "$binary" in
    '') printf '%s NOT RUN (no executable specified)\n' "$label"; return 1 ;;
    /*) ;;
    *) binary=$PWD/$binary ;;
  esac
  if [[ ! -f $binary || ! -x $binary ]] ||
     ! version=$("$binary" -c 'printf "%s" "${BASH_VERSION:?}"'); then
    printf '%s NOT RUN (unavailable executable)\n' "$label"
    return 1
  fi
  case "$label/$version" in
    5.x/5.*|3.2/3.2.*) ;;
    *) printf '%s NOT RUN (actual %s)\n' "$label" "$version"; return 1 ;;
  esac

  if ! mkdir "$tmp/$label" || ! ln -s "$binary" "$tmp/$label/bash"; then
    printf '%s FAIL (%s, PATH setup failed)\n' "$label" "$version"
    return 1
  fi
  export PATH="$tmp/$label:$PATH"
  if "$tmp/probe" "$version" "$binary" && "$scripts/verify.sh"; then
    printf '%s PASS (%s)\n' "$label" "$version"
  else
    status=$?
    printf '%s FAIL (%s, exit %d)\n' "$label" "$version" "$status"
    return "$status"
  fi
)

result=0
run_row 5.x "${BASH5_BIN-}" || result=1
run_row 3.2 "${BASH32_BIN-}" || result=1
exit "$result"
