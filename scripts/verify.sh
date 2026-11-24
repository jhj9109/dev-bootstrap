#!/usr/bin/env bash
set -eu
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
[[ -f setup.sh && -f bootstrap.sh && -d tests ]] || { echo 'Invalid repository root' >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Include pending new scripts. A locally missing indexed script must fail validation.
git ls-files --cached --others --exclude-standard -z -- '*.sh' > "$tmp/scripts"
tests=()
checked=0
while IFS= read -r -d '' file; do
  [[ -f "$file" && -s "$file" ]] || { printf 'Empty or missing shell script: %s\n' "$file" >&2; exit 1; }
  bash -n "./$file" || { printf 'Syntax failed: %s\n' "$file" >&2; exit 1; }
  checked=$((checked + 1))
  case "$file" in
    tests/*) case "${file##*/}" in test_*.sh) tests+=("$file") ;; esac ;;
  esac
done < "$tmp/scripts"

# Bash 3.2 treats an empty array as unset under nounset.
[[ -n ${tests[0]-} ]] || { echo 'No test_*.sh scripts found under tests/' >&2; exit 1; }
printf 'Syntax OK: %d scripts\n' "$checked"
count=0
for file in "${tests[@]}"; do
  count=$((count + 1))
  mkdir "$tmp/home-$count"
  printf 'Testing %s\n' "$file"
  env -i PATH="$PATH" HOME="$tmp/home-$count" GIT_CONFIG_NOSYSTEM=1 \
    GIT_ALLOW_PROTOCOL=file GIT_TERMINAL_PROMPT=0 bash "./$file" || {
      status=$?
      printf 'Test failed (%d): %s\n' "$status" "$file" >&2
      exit "$status"
    }
done
printf 'Passed: %d test scripts\n' "$count"
