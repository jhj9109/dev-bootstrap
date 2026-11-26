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

config_validate_environment() {
  case "$1" in
    classroom|minimal) return 0 ;;
    *) log_error 'Invalid environment'; return 2 ;;
  esac
}

# Bash 3.2 treats an empty array as unset in parameter expansions with
# nounset. Its declaration still distinguishes () from an absent variable.
config_array_destination() {
  local declaration
  declaration=$(declare -p ENABLED_MODULES 2>/dev/null) || return 0
  case "$declaration" in
    'declare -a '*|'declare -ax '*) return 0 ;;
    *) log_error 'ENABLED_MODULES must be a writable indexed array'; return 2 ;;
  esac
}

config_validate_ids() {
  local id seen=' '
  for id do
    registry_index "$id" >/dev/null || { log_error 'Unknown module in ENABLED_MODULES'; return 2; }
    [[ $seen != *" $id "* ]] || { log_error "Duplicate module: $id"; return 2; }
    seen="$seen$id "
  done
}

config_check_module_array() {
  local i
  declare -p ENABLED_MODULES >/dev/null 2>&1 || { log_error 'Missing ENABLED_MODULES'; return 2; }
  config_array_destination || return 2
  for ((i=0; i<${#ENABLED_MODULES[@]}; i++)); do
    [[ ${ENABLED_MODULES[i]+set} ]] || { log_error 'Sparse ENABLED_MODULES'; return 2; }
  done
}

config_resolve_modules() {
  if ! declare -p ENABLED_MODULES >/dev/null 2>&1; then
    [[ $ENVIRONMENT == classroom ]] || { log_error 'Missing ENABLED_MODULES'; return 2; }
    ENABLED_MODULES=(workspace git github shell)
    [[ $INSTALL_NODE != true ]] || ENABLED_MODULES+=(node)
    [[ $INSTALL_PYTHON != true ]] || ENABLED_MODULES+=(python)
    [[ $INSTALL_ITERM != true ]] || ENABLED_MODULES+=(iterm)
    ENABLED_MODULES+=(repository)
  fi
  config_check_module_array || return 2
  config_validate_ids ${ENABLED_MODULES[@]+"${ENABLED_MODULES[@]}"}
}

config_write_snapshot() {
  local key i
  for key do
    if [[ $key == ENABLED_MODULES ]]; then
      # Only resolved arrays reach the wire. Count zero is an explicit empty list.
      config_check_module_array || return 2
      printf '%s\0array\0%s\0' "$key" "${#ENABLED_MODULES[@]}" || return 2
      for ((i=0; i<${#ENABLED_MODULES[@]}; i++)); do
        printf '%s\0' "${ENABLED_MODULES[i]}" || return 2
      done
    else
      config_plain_scalar "$key" || return 2
      [[ ${!key+x} ]] || { log_error "Missing configuration key: $key"; return 2; }
      printf '%s\0scalar\0%s\0' "$key" "${!key}" || return 2
    fi
  done
}

config_read_field() {
  IFS= LC_ALL=C read -r -d '' "$1" || { log_error 'Incomplete configuration snapshot'; return 2; }
}

# The caller supplies the expected schema. Stage and validate every field and
# destination before publishing either the scalars or the array.
config_apply_snapshot() {
  local key field type count i=0
  local -a values=() modules=()
  for key do
    config_read_field field && config_read_field type || return 2
    [[ $key == "$field" ]] || { log_error 'Unexpected configuration key'; return 2; }
    if [[ $key == ENABLED_MODULES ]]; then
      [[ $type == array ]] || { log_error 'Expected array record'; return 2; }
      config_array_destination && config_read_field count || return 2
      [[ $count =~ ^(0|[1-9][0-9]*)$ ]] || { log_error 'Invalid module count'; return 2; }
      # Compare the canonical count as text. Never evaluate wire data as arithmetic.
      while [[ ${#modules[@]} != "$count" ]]; do
        (( ${#modules[@]} < ${#REGISTRY_IDS[@]} )) || { log_error 'Invalid module count'; return 2; }
        config_read_field field || return 2
        modules+=("$field")
      done
      config_validate_ids ${modules[@]+"${modules[@]}"} || return 2
    else
      [[ $type == scalar ]] || { log_error 'Expected scalar record'; return 2; }
      config_plain_scalar "$key" && config_read_field field || return 2
      values+=("$field")
    fi
  done
  if IFS= LC_ALL=C read -r -d '' field || [[ -n $field ]]; then
    log_error 'Unexpected data after configuration snapshot'; return 2
  fi
  for key do
    if [[ $key == ENABLED_MODULES ]]; then
      ENABLED_MODULES=(${modules[@]+"${modules[@]}"})
    else
      printf -v "$key" '%s' "${values[i]}" || return 2
      i=$((i+1))
    fi
  done
}

# Called in a process substitution. Only the four account fields cross back
# into the candidate. An unset field falls through to the current lower layer.
config_write_accounts() {
  local key
  local -a account_fallback=()
  for key in "${REGISTRY_ACCOUNT_KEYS[@]}"; do account_fallback+=("${!key}"); done
  readonly -a account_fallback
  source "$1" >&2 || { log_error 'Cannot load accounts.conf'; return 2; }
  local i=0
  for key in "${REGISTRY_ACCOUNT_KEYS[@]}"; do
    config_plain_scalar "$key" || return 2
    [[ ${!key+x} ]] || printf -v "$key" '%s' "${account_fallback[i]}" || return 2
    i=$((i+1))
  done
  config_write_snapshot "${REGISTRY_ACCOUNT_KEYS[@]}"
}

config_write_candidate() (
  local root=$1 file index key
  local -r config_requested_environment=$2
  local DEFAULT_ENVIRONMENT=classroom
  local -a owned
  shift 2
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

  # Configuration layers are trusted Bash. Keep their output off the wire.
  source "$root/config/defaults.conf" >&2 || return 2
  if [[ -z $config_requested_environment ]]; then config_plain_scalar DEFAULT_ENVIRONMENT || return 2; fi
  local -r config_selected_environment="${config_requested_environment:-${DEFAULT_ENVIRONMENT-}}"
  config_validate_environment "$config_selected_environment" || return 2
  ENVIRONMENT=$config_selected_environment
  file="$root/config/environments/$config_selected_environment.conf"
  if [[ -f $file ]]; then
    source "$file" >&2 || return 2
  elif [[ $config_selected_environment != classroom || -e $file || -L $file ]]; then
    log_error "Cannot read environment: $config_selected_environment"; return 2
  fi
  if [[ -e $root/config/profiles.conf || -L $root/config/profiles.conf ]]; then
    [[ -f $root/config/profiles.conf ]] || { log_error 'Cannot read profiles.conf'; return 2; }
    source "$root/config/profiles.conf" >&2 || return 2
  fi
  ENVIRONMENT=$config_selected_environment
  for key in "${REGISTRY_COMMON_KEYS[@]}"; do
    [[ ${!key+x} ]] || printf -v "$key" '%s' '' || return 2
  done
  file="$root/config/accounts.conf"
  if [[ -e $file || -L $file ]]; then
    [[ -f $file ]] || { log_error 'Cannot read accounts.conf'; return 2; }
    config_apply_snapshot "${REGISTRY_ACCOUNT_KEYS[@]}" < <(config_write_accounts "$file") || return 2
  fi
  config_resolve_modules || return 2
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
  names+=(ENABLED_MODULES)
  snapshot=$(mktemp "${TMPDIR:-/tmp}/dev-bootstrap-config.XXXXXXXX") || return 1
  config_write_candidate "$1" "${2-}" "${names[@]}" > "$snapshot" &&
    config_apply_snapshot "${names[@]}" < "$snapshot" || status=2
  rm -f -- "$snapshot"
  return "$status"
}
