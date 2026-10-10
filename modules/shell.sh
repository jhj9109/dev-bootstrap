#!/usr/bin/env bash
shell_configure() {
  local rc="$HOME/.zshrc" managed="$HOME/.config/dev-bootstrap/env.zsh" marker='# Dev Bootstrap managed environment'
  [[ ! -L "$rc" && ! -L "$managed" ]] || { log_error 'Refusing symlinked shell configuration'; return 1; }
  mkdir -p "$HOME/.config/dev-bootstrap" || return 1
  local tmp; tmp="$(mktemp "$HOME/.config/dev-bootstrap/.env.XXXXXXXX")" || return 1
  cat > "$tmp" <<'ENV'
# Managed by Dev Bootstrap. Edit config/defaults.conf instead.
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
fi
export PATH="$HOME/.local/bin:$PATH"
ENV
  chmod 600 "$tmp" && mv "$tmp" "$managed" || return 1
  [[ -f "$rc" ]] || (umask 077; : > "$rc") || return 1
  if ! grep -Fxq "$marker" "$rc"; then
    printf '\n%s\n[ -f "$HOME/.config/dev-bootstrap/env.zsh" ] && . "$HOME/.config/dev-bootstrap/env.zsh"\n' "$marker" >> "$rc" || return 1
  fi
  log_ok 'zsh initialization configured (open a new terminal to apply)'
}
