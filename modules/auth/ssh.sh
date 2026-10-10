#!/usr/bin/env bash
ssh_setup() {
  local profile="$1" no_passphrase="$2"
  profile_load "$profile" || return $?
  require_command ssh-keygen || { log_error 'ssh-keygen is required'; return 3; }
  local sshdir="$HOME/.ssh" config="$HOME/.ssh/config" managed="$HOME/.ssh/dev-bootstrap.conf"
  if [[ -L "$sshdir" || -L "$config" || -L "$managed" || -L "$PROFILE_KEY" ]]; then
    log_error 'Refusing symlinked SSH paths'; return 1
  fi
  (umask 077; mkdir -p "$sshdir") || return 1
  chmod 700 "$sshdir" || return 1
  if [[ -e "$PROFILE_KEY" ]]; then
    [[ -f "$PROFILE_KEY" ]] || { log_error 'SSH key path is not a regular file'; return 1; }
    ssh-keygen -l -f "$PROFILE_KEY" >/dev/null 2>&1 || { log_error 'Existing private key is not readable/valid'; return 1; }
    log_info "Reusing existing SSH key: $PROFILE_KEY"
  else
    if [[ "$no_passphrase" == true ]]; then
      ssh-keygen -q -t ed25519 -f "$PROFILE_KEY" -N '' -C "$PROFILE_EMAIL" || return 1
      log_warn 'SSH key created without passphrase by explicit request'
    else
      [[ -t 0 ]] || { log_error 'Key creation needs an interactive terminal (or explicitly --no-passphrase)'; return 4; }
      ssh-keygen -t ed25519 -f "$PROFILE_KEY" -C "$PROFILE_EMAIL" || return 1
    fi
  fi
  chmod 600 "$PROFILE_KEY" || return 1
  if [[ ! -f "$PROFILE_KEY.pub" ]]; then
    ssh-keygen -y -f "$PROFILE_KEY" > "$PROFILE_KEY.pub" || return 1
  fi
  chmod 644 "$PROFILE_KEY.pub" || return 1
  local include='Include ~/.ssh/dev-bootstrap.conf'
  if [[ ! -f "$config" ]]; then
    (umask 077; : > "$config") || return 1
  fi
  chmod 600 "$config" || return 1
  # Include must precede Host * blocks so it is effective regardless of existing config.
  if ! grep -Fxq "$include" "$config"; then
    local tmp
    tmp="$(mktemp "$sshdir/.config.XXXXXXXX")" || return 1
    { printf '%s\n' "$include"; cat "$config"; } > "$tmp" || { rm -f "$tmp"; return 1; }
    chmod 600 "$tmp" && mv "$tmp" "$config" || return 1
  fi
  local tmp
  tmp="$(mktemp "$sshdir/.managed.XXXXXXXX")" || return 1
  # Managed file is reconstructed from known profiles with existing private keys.
  local p alias key
  for p in personal secondary; do
    alias="github-$p"; key="$sshdir/dev-bootstrap-$p"
    if [[ -f "$key" ]]; then
      printf 'Host %s\n    HostName github.com\n    User git\n    IdentityFile %s\n    IdentitiesOnly yes\n\n' "$alias" "$key" >> "$tmp"
    fi
  done
  chmod 600 "$tmp" && mv "$tmp" "$managed" || return 1
  if require_command ssh; then
    ssh -G "$PROFILE_ALIAS" 2>/dev/null | grep -qi '^hostname github.com$' || { log_error 'SSH config verification failed'; return 5; }
  fi
  log_ok "SSH configured: $PROFILE_ALIAS"
  printf 'Register this PUBLIC key in GitHub Settings > SSH and GPG keys:\n'
  cat "$PROFILE_KEY.pub"
  printf '\nThen verify with: ./setup.sh doctor github --profile %s\n' "$profile"
}
ssh_doctor() {
  local profile="$1"
  profile_load "$profile" || return $?
  if [[ ! -f "$PROFILE_KEY" || ! -f "$PROFILE_KEY.pub" ]]; then
    log_warn "SSH key missing for $profile"; return 4
  fi
  if ! require_command ssh; then log_error 'ssh unavailable'; return 3; fi
  log_info "Testing SSH authentication for $PROFILE_ALIAS (network required)"
  local output status
  output="$(ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$PROFILE_ALIAS" 2>&1)"; status=$?
  # GitHub's successful SSH authentication returns exit code 1.
  if [[ "$output" == *'successfully authenticated'* && "$output" == *"$PROFILE_USER"* ]]; then
    log_ok "$output"; return 0
  fi
  log_warn "GitHub SSH verification unsuccessful (exit $status): $output"
  return 4
}
