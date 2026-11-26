#!/usr/bin/env bash

github_check() {
  profile_load "${github_profile:-$DEFAULT_GITHUB_PROFILE}" || return $?
  case "${github_method:-$DEFAULT_AUTH_METHOD}" in
    ssh) ssh_local_status ;;
    gh) gh_local_status ;;
    *) return 2 ;;
  esac
}

github_apply() {
  profile_load "${github_profile:-$DEFAULT_GITHUB_PROFILE}" || return $?
  case "${github_method:-$DEFAULT_AUTH_METHOD}" in
    ssh) ssh_setup ;;
    gh) gh_setup ;;
    *) return 2 ;;
  esac
}

register_module --id github --name GitHub --platforms 'Darwin Linux' \
  --prerequisites 'SSH setup needs ssh and ssh-keygen; remote access needs a registered key. The gh method needs gh, Git and the selected account.' \
  --check github_check --apply github_apply --verify github_check
