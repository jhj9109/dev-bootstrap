#!/usr/bin/env bash

node_defaults() { NODE_VERSION=24; }

node_validate() {
  [[ $NODE_VERSION =~ ^[0-9]+([.][0-9]+){0,2}$ ]] || { log_error 'Invalid Node version'; return 2; }
}

# Inspect again in apply: each Runner hook has its own shell and nvm function.
node_inspect() {
  shell_state=0
  shell_runtime_status || shell_state=$?
  case "$shell_state" in 0|10) ;; *) return "$shell_state" ;; esac
  nvm_state=0
  node_load_nvm || nvm_state=$?
  [[ $nvm_state == 0 ]] || return "$nvm_state"
  resolved=$(node_resolve "$requested_node") || return 1
  default_version=$(node_resolve default) || return 1
  [[ -n $resolved && $default_version == "$resolved" && $shell_state == 0 ]] || return 10
}

node_check() {
  local shell_target=node
  local requested_node=${node_request:-$NODE_VERSION} shell_state nvm_state resolved default_version
  node_inspect
}

node_apply() {
  local shell_target=node
  local requested_node=${node_request:-$NODE_VERSION} shell_state nvm_state resolved default_version rc=0
  node_inspect || rc=$?
  [[ $rc == 10 ]] || return "$rc"

  if [[ $nvm_state == 10 ]]; then
    node_bootstrap_nvm || return 1
    [[ -s $NVM_DIR/nvm.sh ]] || { log_error 'nvm installation verification failed'; return 5; }
    rc=0
    node_inspect || rc=$?
    [[ $rc == 10 ]] || return "$rc"
    [[ $nvm_state == 0 ]] || return 5
  fi
  if [[ -z $resolved ]]; then
    nvm install "$requested_node" || return 1
    resolved=$(node_resolve "$requested_node") || return 5
    [[ -n $resolved ]] || { log_error 'Node installation verification failed'; return 5; }
    nvm use "$requested_node" || return 1
    default_version=$(node_resolve default) || return 1
  fi
  if [[ $default_version != "$resolved" ]]; then
    nvm alias default "$requested_node" || return 1
  fi
  if [[ $shell_state == 10 ]]; then shell_configure || return 1; fi
}

register_module --id node --name Node.js --platforms 'Darwin Linux' \
  --depends shell \
  --keys 'NODE_VERSION' --defaults node_defaults --validate node_validate \
  --prerequisites 'Bootstrapping nvm needs curl and Bash.' \
  --check node_check --apply node_apply --verify node_check

node_command_install() {
  run_install node "$@"
}
register_command 'install node' node_command_install '[--version X.Y.Z]' 5 'Install Node.js'
