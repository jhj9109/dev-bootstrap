#!/usr/bin/env bash
python_check() {
  local version="$1" method="$2"
  if [[ "$method" == uv ]]; then
    [[ -x "$HOME/.local/bin/uv" ]] || return 1
    "$HOME/.local/bin/uv" python find "$version" --no-python-downloads >/dev/null 2>&1
  else
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    [[ -x "$HOME/.local/python-$version/bin/python${version%.*}" ]]
  fi
}
python_install() {
  local version="$1" method="$2" installer='' url='https://astral.sh/uv/install.sh'
  if [[ "$method" == uv ]]; then
    if [[ ! -x "$HOME/.local/bin/uv" ]]; then
      installer="$(mktemp)" || return 1
      if ! curl --fail --location --show-error --silent --retry 2 "$url" -o "$installer"; then rm -f "$installer"; return 1; fi
      log_info 'Installing uv using official Astral installer'
      UV_NO_MODIFY_PATH=1 sh "$installer" || { rm -f "$installer"; return 1; }
      rm -f "$installer"
    fi
    "$HOME/.local/bin/uv" python install "$version" || return 1
    shell_configure || return 1
    python_check "$version" uv || { log_error 'uv Python verification failed'; return 5; }
    log_ok "Python available: $($HOME/.local/bin/uv python find "$version" --no-python-downloads)"
  else
    python_source_install "$version" || return $?
  fi
}
python_source_install() {
  local version="$1" archive='' dir='' prefix='' builddir='' jobs='2'
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { log_error 'Source build requires full X.Y.Z version'; return 2; }
  for cmd in curl tar make; do require_command "$cmd" || { log_error "Missing $cmd"; return 3; }; done
  prefix="$HOME/.local/python-$version"
  [[ ! -L "$prefix" ]] || { log_error 'Refusing symlinked Python prefix'; return 1; }
  builddir="$(mktemp -d)" || return 1
  archive="$builddir/Python-$version.tgz"
  dir="$builddir/Python-$version"
  if ! curl --fail --location --show-error --silent --retry 2 "https://www.python.org/ftp/python/$version/Python-$version.tgz" -o "$archive"; then rm -rf "$builddir"; return 1; fi
  # Extract only the official archive into an isolated temporary directory.
  if ! tar -xzf "$archive" -C "$builddir" || [[ ! -f "$dir/configure" ]]; then rm -rf "$builddir"; return 1; fi
  if require_command sysctl; then jobs="$(sysctl -n hw.ncpu 2>/dev/null || printf 2)"; fi
  [[ "$jobs" =~ ^[1-9][0-9]*$ ]] || jobs=2
  (cd "$dir" && ./configure --prefix="$prefix" && make -j "$jobs" && make install) || { log_error 'Python source build failed'; rm -rf "$builddir"; return 1; }
  rm -rf "$builddir"
  python_check "$version" source || { log_error 'Python source build verification failed'; return 5; }
  log_ok "Python installed at $prefix (not added to PATH; use its full path or venv)"
}
