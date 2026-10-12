#!/usr/bin/env bash
iterm_check() {
  [[ -d "$HOME/Applications/iTerm.app" || -d "$HOME/Applications/iTerm2.app" || -d /Applications/iTerm.app || -d /Applications/iTerm2.app ]]
}

iterm_install() {
  [[ "$(uname -s)" == Darwin ]] || { log_error 'iTerm2 requires macOS'; return 3; }
  for cmd in curl ditto; do require_command "$cmd" || { log_error "Missing $cmd"; return 3; }; done
  if iterm_check; then log_ok 'iTerm2 already installed'; return 0; fi

  local tmp='' zip='' app='' bytes='' start=$SECONDS
  local -a curl_progress=(--no-progress-meter)
  tmp="$(mktemp -d)" || { log_error 'Cannot create temporary directory'; return 1; }
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
    rm -rf "$tmp"
    return 1
  fi
  if [[ ! -s "$zip" ]]; then
    log_error 'iTerm2 download produced an empty archive'
    rm -rf "$tmp"
    return 5
  fi
  bytes="$(wc -c < "$zip" | tr -d '[:space:]')"
  log_ok "iTerm2: download complete (${bytes} bytes, $((SECONDS - start))s elapsed)"

  log_info 'iTerm2: extracting archive (this may take a while)'
  if ! ditto -x -k "$zip" "$tmp/extracted"; then
    log_error 'iTerm2 archive extraction failed'
    rm -rf "$tmp"
    return 1
  fi
  app="$tmp/extracted/iTerm.app"
  [[ -d "$app" ]] || app="$tmp/extracted/iTerm2.app"
  if [[ ! -d "$app" ]]; then
    log_error 'Expected iTerm application not found in archive'
    rm -rf "$tmp"
    return 5
  fi

  if ! mkdir -p "$HOME/Applications"; then
    log_error 'Cannot create ~/Applications'
    rm -rf "$tmp"
    return 1
  fi
  if [[ -e "$HOME/Applications/$(basename "$app")" ]]; then
    log_error 'Destination already exists; refusing to overwrite'
    rm -rf "$tmp"
    return 1
  fi
  log_info 'iTerm2: copying application into ~/Applications'
  if ! ditto "$app" "$HOME/Applications/$(basename "$app")"; then
    log_error 'iTerm2 application copy failed'
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
  iterm_check || { log_error 'iTerm2 verification failed'; return 5; }
  log_ok "iTerm2 installed in ~/Applications ($((SECONDS - start))s total)"
}
