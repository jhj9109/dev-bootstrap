#!/usr/bin/env bash
iterm_system_installed() {
  [[ -d /Applications/iTerm.app || -d /Applications/iTerm2.app ]]
}

iterm_check() {
  [[ -d "$HOME/Applications/iTerm.app" || -d "$HOME/Applications/iTerm2.app" ]] || iterm_system_installed
}

iterm_safe_destination() {
  local dir="$HOME/Applications" path
  for path in "$HOME" "$dir" "$dir/iTerm.app" "$dir/iTerm2.app"; do
    if [[ -L $path || ( -e $path && ( ! -d $path || ! -x $path ) ) ]]; then
      log_error "Unsafe iTerm2 destination: $path"
      return 1
    fi
  done
}

iterm_publish_bundle() (
  local app=$1 bundle=${1##*/} stage
  iterm_safe_destination || return 1
  mkdir -p -- "$HOME/Applications" || return 1
  cd -P -- "$HOME/Applications" || return 1
  iterm_safe_destination || return 1
  stage=$(mktemp -d .iterm-install.XXXXXXXX) || return 1
  trap 'rm -rf -- "$stage"' EXIT
  log_info 'iTerm2: copying application into ~/Applications'
  if ! ditto "$app" "$stage/$bundle"; then
    log_error 'iTerm2 application copy failed'
    return 1
  fi
  [[ -d "$stage/$bundle" && ! -L "$stage/$bundle" ]] || return 5
  iterm_safe_destination || return 1
  # Both paths are on the same filesystem. Publish only a complete bundle.
  [[ . -ef "$HOME/Applications" ]] || return 1
  mv -n "$stage/$bundle" . || return 1
  [[ ! -e "$stage/$bundle" ]] || { log_error 'Destination already exists'; return 1; }
)

iterm_install() (
  local tmp='' zip='' app='' bytes='' start=$SECONDS
  local -a curl_progress=(--no-progress-meter)
  tmp="$(mktemp -d)" || { log_error 'Cannot create temporary directory'; return 1; }
  trap 'rm -rf -- "$tmp"' EXIT
  [[ $tmp == /* ]] || tmp="$PWD/$tmp"
  zip="$tmp/iterm.zip"

  # curl's progress bar is meaningful on a terminal, but noisy in redirected logs.
  if [[ -t 2 ]]; then curl_progress=(--progress-bar); fi
  log_info 'iTerm2: downloading stable release (progress shown on terminal)'
  log_info 'iTerm2: aborting stalled transfers after 30 seconds below 1 KiB/s; retrying up to 2 times'
  if ! curl --fail --location --show-error "${curl_progress[@]}" \
      --connect-timeout 15 --speed-limit 1024 --speed-time 30 \
      --retry 2 --retry-delay 2 \
      'https://iterm2.com/downloads/stable/latest' -o "$zip"; then
    log_error 'iTerm2 download failed (network, server, or stalled transfer). Try again later.'
    return 1
  fi
  if [[ ! -s "$zip" ]]; then
    log_error 'iTerm2 download produced an empty archive'
    return 5
  fi
  bytes="$(wc -c < "$zip" | tr -d '[:space:]')"
  log_ok "iTerm2: download complete (${bytes} bytes, $((SECONDS - start))s elapsed)"

  log_info 'iTerm2: extracting archive (this may take a while)'
  if ! ditto -x -k "$zip" "$tmp/extracted"; then
    log_error 'iTerm2 archive extraction failed'
    return 1
  fi
  app="$tmp/extracted/iTerm.app"
  [[ -d "$app" ]] || app="$tmp/extracted/iTerm2.app"
  if [[ ! -d "$app" || -L "$app" || -L "$tmp/extracted" ]]; then
    log_error 'Expected iTerm application not found in archive'
    return 5
  fi

  iterm_publish_bundle "$app"
)
