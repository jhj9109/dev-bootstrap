#!/usr/bin/env bash
set -o pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
for lib in logger common config platform profiles; do
  # shellcheck source=/dev/null
  source "$ROOT_DIR/lib/$lib.sh" || exit 1
done
for module in git auth/ssh auth/gh github shell node python iterm workspace repository; do
  # shellcheck source=/dev/null
  source "$ROOT_DIR/modules/$module.sh" || exit 1
done
for core in cli menu; do
  # shellcheck source=/dev/null
  source "$ROOT_DIR/core/$core.sh" || exit 1
done
main "$@"
