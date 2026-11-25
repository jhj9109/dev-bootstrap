#!/usr/bin/env bash

node_load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  local path
  for path in "$NVM_DIR" "$NVM_DIR/alias" "$NVM_DIR/versions" "$NVM_DIR/versions/node"; do
    if [[ -L $path || ( -e $path && ( ! -d $path || ! -r $path || ! -x $path ) ) ]]; then
      log_error "Unsafe nvm directory: $path"; return 1
    fi
  done
  for path in "$NVM_DIR/nvm.sh" "$NVM_DIR/alias/default"; do
    if [[ -L $path || ( -e $path && ( ! -f $path || ! -r $path ) ) ]]; then
      log_error "Cannot safely read $path"; return 1
    fi
  done
  if [[ ! -e $NVM_DIR/nvm.sh ]]; then
    # The official installer can update a pre-existing checkout. Leave an
    # incomplete or user-managed directory for the user to inspect.
    if [[ -d $NVM_DIR ]]; then
      local entries
      entries=$(LC_ALL=C ls -Aq "$NVM_DIR") || return 1
      [[ -z $entries ]] || { log_error 'Existing ~/.nvm has no nvm.sh'; return 1; }
    fi
    return 10
  fi
  unset -f nvm || return 1
  if [[ ! -s $NVM_DIR/nvm.sh ]] || ! . "$NVM_DIR/nvm.sh" --no-use || ! declare -F nvm >/dev/null; then
    log_error 'Cannot load nvm'; return 1
  fi
}

# Return the resolved local version, or an empty value for an ordinary miss.
node_resolve() {
  local query=$1 output rc=0
  output=$(nvm version "$query" 2>&1) || rc=$?
  if [[ $rc == 3 && $output == N/A ]]; then return 0; fi
  if [[ $rc == 0 ]]; then
    if [[ $output =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      if [[ $query == default || $output == "v$query" || $output == "v$query".* ]]; then
        printf '%s\n' "$output"; return 0
      fi
    elif [[ $query == default && ( $output == system || $output =~ ^iojs-v[0-9]+\.[0-9]+\.[0-9]+$ ) ]]; then
      printf '%s\n' "$output"; return 0
    fi
  fi
  log_error "Unexpected nvm version result for $query (exit $rc)"
  return 1
}

node_bootstrap_nvm() (
  local installer url='https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh'
  installer=$(mktemp) || return 1
  trap 'rm -f -- "$installer"' EXIT
  curl --fail --location --show-error --silent --retry 2 "$url" -o "$installer" || return 1
  log_info 'Installing nvm v0.40.3 from official nvm-sh repository'
  PROFILE=/dev/null NVM_DIR="$HOME/.nvm" bash "$installer" || return 1
)
