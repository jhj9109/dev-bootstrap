#!/usr/bin/env bash
set -eu
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
mkdir scripts tests
cp "$root"/scripts/verify{,-matrix}.sh scripts/
printf '# fixture\n' > setup.sh
cp setup.sh bootstrap.sh
ln -s "$BASH" 'selected shell'
cat > tests/test_child.sh <<'CHILD'
#!/usr/bin/env bash
[[ $BASH -ef './selected shell' ]] && ./entry
CHILD
cat > entry <<'ENTRY'
#!/usr/bin/env bash
[[ $BASH -ef './selected shell' ]] &&
  bash -c '[[ $BASH -ef "./selected shell" ]]'
ENTRY
chmod +x entry

# Run a minimal real suite in one row. The other row must never silently pass.
case "$BASH_VERSION" in
  5.*) label=5.x; other=3.2; export BASH5_BIN='./selected shell' BASH32_BIN=./missing ;;
  3.2.*) label=3.2; other=5.x; export BASH32_BIN='./selected shell' BASH5_BIN=./missing ;;
  *) echo 'Matrix fixture requires Bash 5.x or 3.2'; exit 0 ;;
esac
check_incomplete() {
  if ./scripts/verify-matrix.sh > result 2>&1; then
    echo 'Incomplete matrix returned success' >&2
    exit 1
  fi
}
check_incomplete
grep -Fqx "$label PASS ($BASH_VERSION)" result
grep -Fqx "$other NOT RUN (unavailable executable)" result
export BASH5_BIN='./selected shell' BASH32_BIN='./selected shell'
echo 'exit 23' >> tests/test_child.sh
check_incomplete
grep -Fqx "$label FAIL ($BASH_VERSION, exit 23)" result
grep -Fqx "$other NOT RUN (actual $BASH_VERSION)" result
unset BASH5_BIN BASH32_BIN
check_incomplete
grep -Fqx '5.x NOT RUN (no executable specified)' result
grep -Fqx '3.2 NOT RUN (no executable specified)' result
echo 'PASS: matrix child shell selection, suite failure and unavailable rows'
