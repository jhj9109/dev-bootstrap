#!/usr/bin/env bash
profile_load() {
  local profile="$1" upper
  case "$profile" in personal|secondary) ;; *) log_error "Unknown profile: $profile"; return 2;; esac
  case "$profile" in personal) upper=PERSONAL;; secondary) upper=SECONDARY;; esac
  PROFILE_NAME="$profile"
  local user_var="GITHUB_${upper}_USER" email_var="GITHUB_${upper}_EMAIL"
  PROFILE_USER="${!user_var:-}"
  PROFILE_EMAIL="${!email_var:-}"
  if [[ -z "$PROFILE_USER" || -z "$PROFILE_EMAIL" ]]; then
    log_error "Set $user_var and $email_var in config/profiles.conf"
    return 2
  fi
  if [[ ! "$PROFILE_USER" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]]; then
    log_error 'Invalid GitHub username'; return 2
  fi
  if [[ "$PROFILE_EMAIL" == *[$'\r\n']* || "$PROFILE_EMAIL" != *@* || "$PROFILE_EMAIL" == -* ]]; then
    log_error 'Invalid email'; return 2
  fi
  PROFILE_ALIAS="github-$profile"
  PROFILE_KEY="$HOME/.ssh/dev-bootstrap-$profile"
}
