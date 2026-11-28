#!/usr/bin/env bash
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
checkout="$tmp/working tree"
fixture="$tmp/test project"
bash "$root/tests/copy-project.sh" "$root" "$checkout"

# Simulate a developer's checkout using only synthetic values.
mkdir "$tmp/originals"
for name in accounts profiles; do
  echo 'return 19' > "$tmp/originals/$name.conf"
done
echo 'invalid fixture repository entry' > "$tmp/originals/repositories.conf"
cp "$tmp/originals/"* "$checkout/config/"
echo '# pending edit' >> "$checkout/lib/common.sh"
echo '# pending file' > "$checkout/modules/pending.sh"

bash "$root/tests/copy-project.sh" "$checkout" "$fixture"
for path in "$tmp/originals/"*; do
  name=${path##*/}
  [[ ! -e "$fixture/config/$name" && ! -L "$fixture/config/$name" ]]
  cmp "$path" "$checkout/config/$name"
done
cmp "$checkout/lib/common.sh" "$fixture/lib/common.sh"
cmp "$checkout/modules/pending.sh" "$fixture/modules/pending.sh"
echo 'PASS: working-tree edits included and private configuration isolated'
