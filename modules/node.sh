#!/usr/bin/env bash
node_check() {
  [[ -s "$HOME/.nvm/nvm.sh" ]] || return 1
  # shellcheck source=/dev/null
  . "$HOME/.nvm/nvm.sh" || return 1
  nvm version "$1" 2>/dev/null | grep -qv '^N/A$'
}
node_install() {
  local version="$1" installer='' url='https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh'
  if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
    [[ ! -e "$HOME/.nvm" || -d "$HOME/.nvm" ]] || { log_error 'Invalid ~/.nvm path'; return 1; }
    installer="$(mktemp)" || return 1
    if ! curl --fail --location --show-error --silent --retry 2 "$url" -o "$installer"; then rm -f "$installer"; return 1; fi
    log_info 'Installing nvm v0.40.3 from official nvm-sh repository'
    PROFILE=/dev/null NVM_DIR="$HOME/.nvm" bash "$installer" || { rm -f "$installer"; return 1; }
    rm -f "$installer"
  fi
  [[ -s "$HOME/.nvm/nvm.sh" ]] || { log_error 'nvm install verification failed'; return 5; }
  # shellcheck source=/dev/null
  . "$HOME/.nvm/nvm.sh" || return 1
  nvm install "$version" || return 1
  nvm alias default "$version" || return 1
  nvm use "$version" || return 1
  shell_configure || return 1
  node_check "$version" || { log_error 'Node verification failed'; return 5; }
  log_ok "Node.js $(node --version) / npm $(npm --version)"
}
