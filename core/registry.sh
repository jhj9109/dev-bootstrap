#!/usr/bin/env bash
# Module IDs index all metadata arrays. Only trusted repository code is sourced.
REGISTRY_ACCOUNT_KEYS=(GITHUB_PERSONAL_USER GITHUB_PERSONAL_EMAIL GITHUB_SECONDARY_USER GITHUB_SECONDARY_EMAIL)
REGISTRY_COMMON_KEYS=(
  ENVIRONMENT TARGET_OS DEFAULT_AUTH_METHOD DEFAULT_GITHUB_PROFILE INSTALL_ITERM INSTALL_NODE INSTALL_PYTHON
  "${REGISTRY_ACCOUNT_KEYS[@]}"
)

registry_reserved_key() {
  case "$1" in
    BASH_*|COMP_*|LC_*|READLINE_*|PROMPT_COMMAND|PROMPT_DIRTRIM|CHILD_MAX|POSIXLY_CORRECT) return 0 ;;
    ROOT_DIR|DEFAULT_ENVIRONMENT|ENABLED_MODULES|REGISTRY_*|RUNNER_*|PROFILE_*|REPO_OWNER|REPO_NAME|NO_PASSPHRASE|INSTALL_METHOD|INSTALL_VERSION) return 0 ;;
    GIT_CONFIG|GIT_CONFIG_*|GIT_DIR|GIT_WORK_TREE|GIT_COMMON_DIR|GIT_INDEX_FILE|GIT_OBJECT_DIRECTORY) return 0 ;;
    GIT_ALTERNATE_OBJECT_DIRECTORIES|GIT_SHALLOW_FILE|GIT_GRAFT_FILE|GIT_IMPLICIT_WORK_TREE|GIT_NAMESPACE|GIT_QUARANTINE_PATH) return 0 ;;
    SSH_AUTH_SOCK|NVM_DIR|GH_NO_UPDATE_NOTIFIER|GH_PROMPT_DISABLED|UV_INSTALL_DIR|UV_NO_MODIFY_PATH) return 0 ;;
  esac
  return 1
}

registry_index() {
  local index
  for ((index=0; index<${#REGISTRY_IDS[@]}; index++)); do
    if [[ ${REGISTRY_IDS[index]} == "$1" ]]; then
      printf '%d\n' "$index"
      return 0
    fi
  done
  return 1
}

registry_error() {
  registry_invalid=1
  log_error "$registry_entry: $*"
  return 2
}

register_module() {
  local id='' name='' platforms='' check='' apply='' verify='' depends='' depends_if='' prerequisites=''
  local keys='' defaults='' validate='' seen=' ' option field hook word prefix
  local LC_ALL=C
  local -a words
  while (( $# )); do
    option=$1
    case "$option" in
      --id|--name|--platforms|--check|--apply|--verify|--depends|--depends-if|--prerequisites|--keys|--defaults|--validate) ;;
      *) registry_error "Unknown module option $option"; return 2 ;;
    esac
    if (( $# < 2 )) || [[ -z $2 || $2 == --* || $seen == *" $option "* ]]; then
      registry_error "Invalid or repeated option $option"; return 2
    fi
    field=${option#--}
    field=${field//-/_}
    printf -v "$field" '%s' "$2"
    seen="$seen$option "
    shift 2
  done

  if registry_index "$id" >/dev/null; then registry_error "Duplicate module ID $id"; return 2; fi
  if [[ ! $id =~ ^[a-z][a-z0-9_]*$ || $id != "$registry_directory" || ! $name =~ [^[:space:]] ]]; then
    registry_error "Invalid module ID or name ($id)"; return 2
  fi
  if [[ -n $keys || -n $defaults || -n $validate ]]; then
    [[ -n $keys && -n $defaults && -n $validate ]] || { registry_error 'Incomplete configuration hooks'; return 2; }
  fi
  for field in check apply verify defaults validate; do
    hook=${!field}
    [[ -z $keys && ( $field == defaults || $field == validate ) ]] && continue
    if [[ ! $hook =~ ^${id}_[a-zA-Z0-9_]+$ ]] || ! declare -F "$hook" >/dev/null; then
      registry_error "Invalid $field hook: $hook"; return 2
    fi
  done

  prefix=$(printf '%s' "$id" | tr '[:lower:]' '[:upper:]')_
  for field in platforms depends keys; do
    [[ $field != platforms && -z ${!field} ]] && continue
    [[ ${!field} =~ ^[A-Za-z0-9_]+(\ [A-Za-z0-9_]+)*$ ]] || { registry_error "Invalid $field list"; return 2; }
    read -r -a words <<< "${!field}"
    seen=' '
    for word in "${words[@]}"; do
      [[ $seen != *" $word "* ]] || { registry_error "Duplicate $field: $word"; return 2; }
      seen="$seen$word "
      case "$field" in
        platforms) [[ $word == Darwin || $word == Linux ]] || { registry_error "Unknown platform $word"; return 2; } ;;
        depends) [[ $word =~ ^[a-z][a-z0-9_]*$ ]] || { registry_error "Invalid dependency $word"; return 2; } ;;
        keys)
          if [[ ! $word =~ ^${prefix}[A-Z0-9_]+$ || $registry_claimed_keys == *" $word "* ]] || registry_reserved_key "$word"; then
            registry_error "Invalid or reserved key $word"; return 2
          fi
          registry_claimed_keys="$registry_claimed_keys$word "
          ;;
      esac
    done
  done
  # A condition may only compare a scalar owned by this module.
  if [[ -n $depends_if ]]; then
    if [[ -z $depends || ! $depends_if =~ ^[A-Z][A-Z0-9_]*=[a-zA-Z0-9_]+$ ||
          " $keys " != *" ${depends_if%%=*} "* ]]; then
      registry_error "Invalid dependency condition: $depends_if"; return 2
    fi
  fi
  REGISTRY_IDS+=("$id")
  REGISTRY_NAMES+=("$name")
  REGISTRY_PLATFORMS+=("$platforms")
  REGISTRY_CHECK+=("$check")
  REGISTRY_APPLY+=("$apply")
  REGISTRY_VERIFY+=("$verify")
  REGISTRY_DEPENDS+=("$depends")
  REGISTRY_DEPENDS_IF+=("$depends_if")
  REGISTRY_PREREQUISITES+=("$prerequisites")
  REGISTRY_KEYS+=("$keys")
  REGISTRY_DEFAULTS+=("$defaults")
  REGISTRY_VALIDATE+=("$validate")
}

discover_modules() {
  local LC_ALL=C IFS=' '
  local root directory registry_directory registry_entry count dependency
  local registry_invalid=0
  local registry_claimed_keys=" ${REGISTRY_COMMON_KEYS[*]} "
  root=$(cd -P -- "$1" && pwd -P) || return 2
  REGISTRY_IDS=() REGISTRY_NAMES=() REGISTRY_PLATFORMS=() REGISTRY_DEPENDS=() REGISTRY_DEPENDS_IF=() REGISTRY_PREREQUISITES=()
  REGISTRY_CHECK=() REGISTRY_APPLY=() REGISTRY_VERIFY=()
  REGISTRY_KEYS=() REGISTRY_DEFAULTS=() REGISTRY_VALIDATE=()
  for registry_entry in "$root"/modules/*/module.sh; do
    [[ -e $registry_entry || -L $registry_entry ]] || continue
    directory=${registry_entry%/*}
    registry_directory=${directory##*/}
    directory=$(cd -P -- "$directory" && pwd -P) || return 2
    if [[ $directory != "$root"/* || -L $registry_entry || ! -f $registry_entry ]]; then
      registry_error 'Unsafe module entry'; return 2
    fi
    count=${#REGISTRY_IDS[@]}
    source "$registry_entry" || { registry_error 'Module load failed'; return 2; }
    if (( registry_invalid || ${#REGISTRY_IDS[@]} != count + 1 )); then
      registry_error 'Expected one valid registration'; return 2
    fi
  done
  for ((count=0; count<${#REGISTRY_IDS[@]}; count++)); do
    for dependency in ${REGISTRY_DEPENDS[count]}; do
      registry_index "$dependency" >/dev/null || { log_error "${REGISTRY_IDS[count]}: unknown dependency $dependency"; return 2; }
    done
  done
}
