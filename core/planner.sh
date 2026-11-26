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

# Traverse only selected edges. Positions never change during validation.
planner_visit() {
  local index=$1 id=${REGISTRY_IDS[$1]} dependency parent
  local IFS=' '
  [[ ${visited[index]-} != done ]] || return 0
  visited[index]=visiting
  for dependency in ${dependencies[index]}; do
    parent=$(registry_index "$dependency") || return 2
    if [[ $dependency == "$id" ]]; then
      log_error "$id depends on itself"; return 2
    elif [[ ! ${positions[parent]+set} ]]; then
      log_error "$id requires missing module $dependency"; return 2
    elif [[ ${visited[parent]-} == visiting ]]; then
      log_error "Dependency cycle: $id -> $dependency"; return 2
    fi
    planner_visit "$parent" || return 2
    if (( positions[parent] > positions[index] )); then
      log_error "$dependency must precede $id"; return 2
    fi
  done
  visited[index]=done
}

planner_validate() {
  local id index position=0
  local -a positions=() dependencies=() visited=()
  config_validate_ids ${ENABLED_MODULES[@]+"${ENABLED_MODULES[@]}"} || return 2
  for id in ${ENABLED_MODULES[@]+"${ENABLED_MODULES[@]}"}; do
    index=$(registry_index "$id") || return 2
    positions[index]=$position
    dependencies[index]=$(planner_dependencies "$index") || return 2
    position=$((position+1))
  done
  for index in "${!positions[@]}"; do
    planner_visit "$index" || return 2
  done
  return 0
}

planner_print() {
  local id index depends step=0
  planner_validate || return $?
  printf 'Environment: %s\nAccount: %s\nAuth method: %s\nAllow unencrypted SSH key: %s\nTarget OS: %s\nModules: %d\n' \
    "$ENVIRONMENT" "$1" "$2" "$3" "$TARGET_OS" "${#ENABLED_MODULES[@]}"
  for id in ${ENABLED_MODULES[@]+"${ENABLED_MODULES[@]}"}; do
    index=$(registry_index "$id") || return 2
    depends=$(planner_dependencies "$index") || return 2
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
