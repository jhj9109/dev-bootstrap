#!/usr/bin/env bash

github_check() {
  profile_load "${github_profile:-$DEFAULT_GITHUB_PROFILE}" || return $?
  case "${github_method:-$DEFAULT_AUTH_METHOD}" in
    ssh)
      ssh_local_status || return $?
      if [[ ${RUNNER_PLANNED:-0} == 1 && ${mode:-} == apply ]]; then
        github_ssh_guidance "$github_profile"
      fi ;;
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

github_command_doctor() {
  parse_options doctor github "$@" || return $?
  github_doctor "$PROFILE" "$METHOD"
}
register_command 'doctor github' github_command_doctor '[--profile personal|secondary] [--method ssh|gh]' 4 'Verify GitHub authentication'

github_command_configure() {
  parse_options configure github "$@" || return $?
  [[ $SCOPE == global && -z $REPO ]] || { log_error '--repo is not supported for GitHub auth'; return 2; }
  configure_github "$PROFILE" "$METHOD" "$NO_PASSPHRASE"
}
register_command 'configure github' github_command_configure '[--profile personal|secondary] [--method ssh|gh] [--no-passphrase]' 3 'Configure GitHub (SSH default)'
