#!/usr/bin/env bash

# Reject attributes that change printf -v semantics (arrays, integers,
# references, readonly, etc.). Exported strings are ordinary destinations.
config_plain_scalar() {
  local declaration
  declaration=$(declare -p "$1" 2>/dev/null) || return 0
  case "$declaration" in
    'declare -- '*|'declare -x '*) return 0 ;;
    *) log_error "Expected writable scalar: $1"; return 2 ;;
  esac
}

config_write_snapshot() {
  local key
  for key do
    config_plain_scalar "$key" || return 2
    [[ ${!key+x} ]] || { log_error "Missing configuration key: $key"; return 2; }
    printf '%s\0%s\0' "$key" "${!key}" || return 2
  done
}

# The caller supplies the expected schema. Never use a name from the wire
# as an assignment target. Stage every value before publishing any of them.
config_apply_snapshot() {
  local key field value i=0
  local -a values=()
  for key do
    IFS= LC_ALL=C read -r -d '' field && [[ $field == "$key" ]] &&
      IFS= LC_ALL=C read -r -d '' value || { log_error 'Invalid configuration snapshot'; return 2; }
    config_plain_scalar "$key" || return 2
    values+=("$value")
  done
  if IFS= LC_ALL=C read -r -d '' field || [[ -n $field ]]; then
    log_error 'Unexpected data after configuration snapshot'; return 2
  fi
  for key do
    printf -v "$key" '%s' "${values[i]}" || return 2
    i=$((i+1))
  done
}

config_write_candidate() (
  local root=$1 index key
  local -a owned
  shift
  unset -v "$@" || return 2
  for ((index=0; index<${#REGISTRY_IDS[@]}; index++)); do
    [[ -n ${REGISTRY_KEYS[index]} ]] || continue
    IFS=' ' read -r -a owned <<< "${REGISTRY_KEYS[index]}"
    # Only the declared defaults leave the hook's process. Its stdout is
    # diagnostic output and cannot become part of the snapshot.
    config_apply_snapshot "${owned[@]}" < <(
      "${REGISTRY_DEFAULTS[index]}" >&2 && config_write_snapshot "${owned[@]}"
    ) || { log_error "${REGISTRY_IDS[index]}: defaults failed"; return 2; }
  done

  # Both files are trusted Bash. They may print diagnostics.
  source "$root/config/defaults.conf" >&2 || return 2
  if [[ -e $root/config/profiles.conf || -L $root/config/profiles.conf ]]; then
    [[ -f $root/config/profiles.conf ]] || { log_error 'Cannot read profiles.conf'; return 2; }
    source "$root/config/profiles.conf" >&2 || return 2
  fi
  for key in "${REGISTRY_COMMON_KEYS[@]}"; do
    [[ ${!key+x} ]] || printf -v "$key" '%s' '' || return 2
  done
  case "$TARGET_OS" in macos) ;; *) log_error 'Unsupported TARGET_OS'; return 2 ;; esac
  case "$DEFAULT_AUTH_METHOD" in ssh|gh) ;; *) log_error 'Invalid authentication method'; return 2 ;; esac
  case "$DEFAULT_GITHUB_PROFILE" in personal|secondary) ;; *) log_error 'Invalid default GitHub profile'; return 2 ;; esac
  for ((index=0; index<${#REGISTRY_IDS[@]}; index++)); do
    [[ -n ${REGISTRY_VALIDATE[index]} ]] || continue
    ( "${REGISTRY_VALIDATE[index]}" ) >&2 || { log_error "${REGISTRY_IDS[index]}: validation failed"; return 2; }
  done
  config_write_snapshot "$@"
)

load_config() {
  local snapshot keys status=0
  declare -p REGISTRY_IDS >/dev/null 2>&1 || { log_error 'Load module registry before configuration'; return 2; }
  local -a names=("${REGISTRY_COMMON_KEYS[@]}") owned
  for keys in "${REGISTRY_KEYS[@]}"; do
    [[ -n $keys ]] || continue
    IFS=' ' read -r -a owned <<< "$keys"
    names+=("${owned[@]}")
  done
  snapshot=$(mktemp "${TMPDIR:-/tmp}/dev-bootstrap-config.XXXXXXXX") || return 1
  config_write_candidate "$1" "${names[@]}" > "$snapshot" &&
    config_apply_snapshot "${names[@]}" < "$snapshot" || status=2
  rm -f -- "$snapshot"
  return "$status"
}
