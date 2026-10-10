#!/usr/bin/env bash
iterm_check() {
  [[ -d "$HOME/Applications/iTerm.app" || -d "$HOME/Applications/iTerm2.app" || -d /Applications/iTerm.app || -d /Applications/iTerm2.app ]]
}
iterm_install() {
  [[ "$(uname -s)" == Darwin ]] || { log_error 'iTerm2 requires macOS'; return 3; }
  for cmd in curl ditto; do require_command "$cmd" || { log_error "Missing $cmd"; return 3; }; done
  if iterm_check; then log_ok 'iTerm2 already installed'; return 0; fi
  local tmp='' zip='' app=''
  tmp="$(mktemp -d)" || return 1
  zip="$tmp/iterm.zip"
  log_info 'Downloading current stable iTerm2 archive'
  if ! curl --fail --location --show-error --silent --retry 2 'https://iterm2.com/downloads/stable/latest' -o "$zip"; then rm -rf "$tmp"; return 1; fi
  if ! ditto -x -k "$zip" "$tmp/extracted"; then rm -rf "$tmp"; return 1; fi
  app="$tmp/extracted/iTerm.app"
  [[ -d "$app" ]] || app="$tmp/extracted/iTerm2.app"
  [[ -d "$app" ]] || { log_error 'Expected iTerm application not found in archive'; rm -rf "$tmp"; return 5; }
  mkdir -p "$HOME/Applications" || { rm -rf "$tmp"; return 1; }
  [[ ! -e "$HOME/Applications/$(basename "$app")" ]] || { log_error 'Destination already exists'; rm -rf "$tmp"; return 1; }
  if ! ditto "$app" "$HOME/Applications/$(basename "$app")"; then rm -rf "$tmp"; return 1; fi
  rm -rf "$tmp"
  iterm_check || { log_error 'iTerm2 verification failed'; return 5; }
  log_ok 'iTerm2 installed in ~/Applications'
}
