#!/usr/bin/env bash

python_validate_request() {
  if [[ $1 == source && ! $2 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error 'Source build requires full X.Y.Z version'; return 2
  fi
}

python_safe_directories() {
  local path
  for path in "$@"; do
    if [[ -L $path || ( -e $path && ( ! -d $path || ! -x $path ) ) ]]; then
      log_error "Unsafe Python installation directory: $path"; return 1
    fi
  done
}

python_uv_status() {
  local output rc=0
  python_safe_directories "$HOME" "$HOME/.local" "$HOME/.local/bin" || return 1
  if [[ -L $uv || ( -e $uv && ( ! -f $uv || ! -x $uv ) ) ]]; then
    log_error 'Cannot safely execute ~/.local/bin/uv'; return 1
  fi
  if [[ ! -e $uv ]]; then
    [[ ! -e ${uv}x && ! -L ${uv}x ]] || { log_error 'Preserving existing uvx installation'; return 1; }
    return 10
  fi
  output=$(LC_ALL=C "$uv" python find "$version" --managed-python --system --no-project \
    --no-python-downloads --no-cache --offline --color never --show-version 2>&1) || rc=$?
  if [[ $rc == 0 && $output =~ ^[0-9]+\.[0-9]+\.[0-9]+$ &&
        ( $output == "$version" || $output == "$version".* ) ]]; then return 0; fi
  if [[ $rc == 2 && $output == "error: No interpreter found for Python $version in managed installations" ]]; then
    return 10
  fi
  log_error "Unexpected uv lookup result for Python $version (exit $rc)"
  return 1
}

python_bootstrap_uv() (
  local installer
  installer=$(mktemp) || return 1
  trap 'rm -f -- "$installer"' EXIT
  curl --fail --location --show-error --silent --retry 2 'https://astral.sh/uv/install.sh' -o "$installer" || return 1
  log_info 'Installing uv using official Astral installer'
  UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 sh "$installer" || return 1
)

python_source_probe() (
  local prefix=$1 binary="$1/bin/python${version%.*}" actual
  python_safe_directories "$prefix" "$prefix/bin" || return 1
  [[ -f $binary && ! -L $binary && -x $binary ]] || return 1
  # Ignore Python environment overrides, user site and startup hooks. Exercise
  # the stdlib from the installation and leave bytecode on disk untouched.
  cd / || return 1
  actual=$("$binary" -E -s -S -B -c '
import json, os, sys
if os.path.realpath(sys.prefix) != os.path.realpath(sys.argv[1]):
    sys.exit(1)
print("%d.%d.%d" % sys.version_info[:3])' "$prefix") || return 1
  [[ $actual == "$version" ]]
)

python_source_install() (
  local prefix="$HOME/.local/python-$version" builddir archive dir staged jobs=2
  mkdir -p "$HOME/.local" && cd -P -- "$HOME/.local" || return 1
  python_safe_directories "$HOME" "$HOME/.local" || return 1
  builddir=$(mktemp -d .python-build.XXXXXXXX) || return 1
  trap 'rm -rf -- "$builddir"' EXIT
  archive="$builddir/Python-$version.tgz"
  dir="$builddir/Python-$version"
  staged="$PWD/$builddir/stage"
  curl --fail --location --show-error --silent --retry 2 "https://www.python.org/ftp/python/$version/Python-$version.tgz" -o "$archive" || return 1
  tar -xzf "$archive" -C "$builddir" || return 1
  [[ ! -L $dir && -f $dir/configure && ! -L $dir/configure ]] || return 1
  if require_command sysctl; then jobs=$(sysctl -n hw.ncpu 2>/dev/null) || jobs=2; fi
  [[ $jobs =~ ^[1-9][0-9]*$ ]] || jobs=2
  (cd "$dir" && ./configure --prefix="$prefix" && make -j "$jobs" && make install DESTDIR="$staged") || {
    log_error 'Python source build failed'; return 1
  }
  python_source_probe "$staged$prefix" || { log_error 'Staged Python failed verification'; return 5; }
  python_safe_directories "$HOME" "$HOME/.local" || return 1
  [[ . -ef "$HOME/.local" && ! -e $prefix && ! -L $prefix ]] || return 1
  mv -n "$staged$prefix" . || return 1
  [[ ! -e $staged$prefix ]] || return 1
)
