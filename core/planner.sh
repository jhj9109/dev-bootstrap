#!/usr/bin/env bash

# Registry conditions are equality tests on validated, module-owned config keys.
planner_dependencies() {
  local index=$1 condition=${REGISTRY_DEPENDS_IF[$1]} key
  if [[ -n $condition ]]; then
    key=${condition%%=*}
    [[ ${!key} == "${condition#*=}" ]] || return 0
  fi
  printf '%s\n' "${REGISTRY_DEPENDS[index]}"
}

# Bulk plans retain profile order. A single request probes its dependency
# closure in postorder, so shared prerequisites are checked once.
planner_visit() {
  local index=$1 id=${REGISTRY_IDS[$1]} dependency parent
  local IFS=' '
  [[ ${visited[index]-} != done ]] || return 0
  visited[index]=visiting
  plan_deps[index]=$(planner_dependencies "$index") || return 2
  for dependency in ${plan_deps[index]}; do
    parent=$(registry_index "$dependency") || return 2
    if [[ $dependency == "$id" ]]; then
      log_error "$id depends on itself"; return 2
    elif [[ -z $requested && ! ${positions[parent]+set} ]]; then
      log_error "$id requires missing module $dependency"; return 2
    elif [[ ${visited[parent]-} == visiting ]]; then
      log_error "Dependency cycle: $id -> $dependency"; return 2
    fi
    planner_visit "$parent" || return 2
    if [[ -z $requested ]] && (( positions[parent] > positions[index] )); then
      log_error "$dependency must precede $id"; return 2
    fi
  done
  visited[index]=done
  if [[ -n $requested ]]; then plan_order+=("$index"); fi
}

# Publish indices and effective edges into the caller's local arrays.
planner_build() {
  local requested=$1 id index
  local -a positions=() visited=()
  plan_order=() plan_deps=()
  if [[ -n $requested ]]; then
    index=$(registry_index "$requested") || { log_error "Unknown module: $requested"; return 2; }
    planner_visit "$index"
    return $?
  fi
  config_validate_ids ${ENABLED_MODULES[@]+"${ENABLED_MODULES[@]}"} || return 2
  for id in ${ENABLED_MODULES[@]+"${ENABLED_MODULES[@]}"}; do
    index=$(registry_index "$id") || return 2
    positions[index]=${#plan_order[@]}
    plan_order+=("$index")
  done
  for index in ${plan_order[@]+"${plan_order[@]}"}; do
    planner_visit "$index" || return 2
  done
  return 0
}

planner_print() {
  local id index depends step=0
  printf 'Environment: %s\nAccount: %s\nAuth method: %s\nAllow unencrypted SSH key: %s\nTarget OS: %s\nModules: %d\n' \
    "$ENVIRONMENT" "$1" "$2" "$3" "$TARGET_OS" "${#ENABLED_MODULES[@]}"
  for index in ${plan_order[@]+"${plan_order[@]}"}; do
    id=${REGISTRY_IDS[index]}
    depends=${plan_deps[index]}
    step=$((step+1))
    printf '%d. %s | depends: %s | platforms: %s\n' "$step" "$id" "${depends:-none}" "${REGISTRY_PLATFORMS[index]}"
    if [[ -n ${REGISTRY_DEPENDS_IF[index]} ]]; then
      printf '   Module dependencies apply when %s\n' "${REGISTRY_DEPENDS_IF[index]}"
    fi
    if [[ -n ${REGISTRY_PREREQUISITES[index]} ]]; then
      printf '   Prerequisites: %s\n' "${REGISTRY_PREREQUISITES[index]}"
    fi
  done
}
