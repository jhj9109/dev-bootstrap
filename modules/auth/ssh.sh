#!/usr/bin/env bash

ssh_safe_paths() {
  local path
  for path in "$HOME" "$HOME/.ssh"; do
    [[ ! -L $path && ( ! -e $path || ( -d $path && -x $path && -O $path ) ) ]] || return 1
  done
  for path in "$HOME/.ssh/config" "$HOME/.ssh/dev-bootstrap.conf" "$PROFILE_KEY" "$PROFILE_KEY.pub"; do
    [[ ! -L $path && ( ! -e $path || ( -f $path && -O $path && -r $path ) ) ]] || return 1
  done
}

ssh_fingerprint() {
  local line bits digest rest
  # Reading the private file on stdin prevents OpenSSH from silently using
  # its adjacent .pub file, including for a passphrase-protected OpenSSH key.
  line=$(ssh-keygen -l -E sha256 -f /dev/stdin < "$1" 2>/dev/null) || return 1
  [[ $line != *$'\n'* ]] || return 1
  read -r bits digest rest <<< "$line"
  [[ $bits =~ ^[0-9]+$ && $digest =~ ^SHA256:[A-Za-z0-9+/=]+$ ]] || return 1
  printf '%s\n' "$digest"
}

ssh_public_matches() {
  local public
  # Never accept a private-key file in the public-key slot.
  awk 'NR != 1 || $1 !~ /^(ssh-|ecdsa-|sk-)/ || NF < 2 { bad=1 } END { exit (bad || NR != 1) }' "$1" || return 1
  public=$(ssh_fingerprint "$1") && [[ $public == "$2" ]]
}

ssh_render_hosts() {
  local profile key
  for profile in "$@"; do
    key="$HOME/.ssh/dev-bootstrap-$profile"
    # Use a home-relative path for homes requiring SSH quoting.
    case "$key" in *[!a-zA-Z0-9/_.-]*) key="~/.ssh/dev-bootstrap-$profile" ;; esac
    printf 'Host github-%s\n    HostName github.com\n    User git\n    IdentityFile %s\n    IdentitiesOnly yes\n\n' "$profile" "$key" || return 1
  done
}

ssh_managed_hosts() {
  local file="$HOME/.ssh/dev-bootstrap.conf" hosts rc
  [[ -e $file ]] || return 0
  for hosts in personal secondary 'personal secondary'; do
    rc=0
    # The candidates are fixed profile IDs, in the order used by v1.
    cmp -s "$file" <(ssh_render_hosts $hosts) || rc=$?
    case "$rc" in 0) printf '%s\n' "$hosts"; return 0 ;; 1) ;; *) return 1 ;; esac
  done
  log_warn 'Review edited SSH managed file'; return 4
}

# Only the observed, literal Host orb layout is supported. Never pass the
# Helper command or a live OrbStack Include to ssh, including for ssh -G.
ssh_orbstack_config() {
  local dir="$HOME/.orbstack" file="$HOME/.orbstack/ssh/config" path mode
  local managed="$HOME/.ssh/dev-bootstrap.conf"
  for path in "$dir" "$dir/ssh" "$file" "$HOME/.ssh/config" "$managed"; do
    [[ $path != "$managed" || -e $path || -L $path ]] || continue
    [[ -O $path && ! -L $path ]] || return 1
    mode=$(ssh_mode "$path") && (( (8#$mode & 022) == 0 )) || return 1
  done
  [[ -d $dir && -d $dir/ssh && -f $file && -r $file ]] || return 1
  LC_ALL=C awk '
    BEGIN {
      helper="/Applications/OrbStack.app/Contents/Frameworks/OrbStack Helper.app/Contents/MacOS/OrbStack Helper"
    }
    /^[[:blank:]]*(#|$)/ { next }
    $0 == "Host orb" && !host { host=1; next }
    !host || seen[$1]++ { exit 1 }
    { fields++ }
    NF==2 && (($1=="Hostname" && $2=="127.0.0.1") ||
              ($1=="Port" && $2 ~ /^[0-9]+$/ && $2+0>0 && $2+0<65536) ||
              ($1=="User" && $2=="default") ||
              ($1=="IdentityFile" && $2=="~/.orbstack/ssh/id_ed25519") ||
              ($1=="IdentitiesOnly" && $2=="yes") ||
              ($1=="UserKnownHostsFile" && $2=="~/.orbstack/ssh/known_hosts") ||
              ($1=="ProxyUseFdpass" && $2=="yes")) { next }
    $1=="ProxyCommand" && $NF ~ /^[0-9]+$/ {
      sub(/^[[:blank:]]*/, "")
      if ($0=="ProxyCommand \047" helper "\047 ssh-proxy-fdpass " $NF) next
    }
    { exit 1 }
    END { if (!host || fields!=8) exit 1 }
  ' "$file"
}

ssh_include_state() {
  if [[ ! -e $HOME/.ssh/config ]]; then echo missing; return; fi
  # Unknown Includes can expand to the managed file. Match exec can execute
  # commands even in ssh -G. Require manual review for ambiguous configurations.
  local state
  state=$(awk -v reserved="${1:-}" '
    /^[[:space:]]*(#|$)/ { next }
    $0 == "Include ~/.ssh/dev-bootstrap.conf" { if (conditional || seen++) bad=1; next }
    $0 == "Include ~/.orbstack/ssh/config" { if (other || seen || orb++) bad=1; next }
    { other=1; line=tolower($0); sub(/^[[:space:]]*/, "", line)
      if (line ~ /^(host|match)([[:space:]=]|$)/) conditional=1
      if (reserved && line ~ /^host([[:space:]=]|$)/) {
        sub(/^host[[:space:]=]+/, "", line); sub(/[[:space:]]+#.*/, "", line)
        gsub(/"/, "", line); count=split(line, patterns, /[[:space:]]+/)
        for (i=1; i<=count; i++) if (patterns[i]==reserved) bad=1
      }
      if (line ~ /^include([[:space:]=]|$)/ ||
          (line ~ /^match([[:space:]=]|$)/ && line ~ /exec/)) bad=1 }
    END {
      if (bad || (orb && other)) print "conflict"
      else if (orb) print (seen ? "orb-present" : "orb-missing")
      else print (seen ? "present" : "missing")
    }
  ' "$HOME/.ssh/config") || return 1
  case "$state" in orb-*) ssh_orbstack_config || state=conflict ;; esac
  printf '%s\n' "$state"
}

ssh_effective_host() {
  local output
  output=$(ssh -G "$@" -o CanonicalizeHostname=no "$PROFILE_ALIAS" 2>/dev/null) || return 1
  awk -v alias="$PROFILE_ALIAS" -v key="$PROFILE_KEY" -v short="~/.ssh/dev-bootstrap-$PROFILE_NAME" '
    $1=="host" && $2==alias { h++ }
    $1=="hostname" && tolower($2)=="github.com" { n++ }
    $1=="user" && $2=="git" { u++ }
    $1=="identitiesonly" && $2=="yes" { o++ }
    $1=="identityfile" { i++; sub(/^identityfile /,""); if ($0==key || $0==short) k++ }
    END { exit !(h==1 && n==1 && u==1 && o==1 && i==1 && k==1) }
  ' <<< "$output"
}

# The only active user settings for a GitHub alias in this layout are the
# managed blocks. Inspect that projection, then recheck its source files.
ssh_orbstack_effective() {
  local expected_include=$1 existing=$2 proposed=$3 latest
  ssh_render_hosts $proposed | ssh_effective_host -F /dev/stdin || return 5
  ssh_safe_paths || return 1
  latest=$(ssh_include_state "$PROFILE_ALIAS") && [[ $latest == "$expected_include" ]] &&
    latest=$(ssh_managed_hosts) && [[ $latest == "$existing" ]] || return 4
}

ssh_mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

ssh_inspect() {
  local config="$HOME/.ssh/config" mode need=0 fingerprint header
  require_command ssh && require_command ssh-keygen || return 3
  ssh_safe_paths || { log_error 'Unsafe SSH configuration path'; return 1; }
  local file
  for file in "$config" "$HOME/.ssh/dev-bootstrap.conf"; do
    [[ -e $file ]] || continue
    mode=$(ssh_mode "$file") || return 1
    (( (8#$mode & 022) == 0 )) || { log_error 'Unsafe SSH configuration permissions'; return 1; }
  done
  hosts=$(ssh_managed_hosts) || return $?
  desired=$hosts
  case " $hosts " in
    *" $PROFILE_NAME "*) ;;
    *) if [[ -z $hosts ]]; then desired=$PROFILE_NAME; else desired='personal secondary'; fi ;;
  esac
  include=$(ssh_include_state "$PROFILE_ALIAS") || return 1
  [[ $include != conflict ]] || { log_warn 'Review conflicting SSH Host, Include or Match directives'; return 4; }
  if [[ $include == orb-* ]]; then
    ssh_orbstack_effective "$include" "$hosts" "$desired" || return $?
    [[ $desired == "$hosts" && $include == orb-present ]] || need=10
  elif [[ $desired != "$hosts" || $include != present ]]; then
    # Test the proposed rules before creating keys or changing either config.
    if ! { ssh_render_hosts $desired && printf 'Host *\n' &&
           { [[ ! -e $config ]] || sed '/^Include ~\/\.ssh\/dev-bootstrap\.conf$/d' "$config"; }; } |
         ssh_effective_host -F /dev/stdin; then
      log_error 'Proposed SSH host has conflicting settings'; return 5
    fi
    need=10
  else
    ssh_effective_host || { log_error 'SSH host verification failed'; return 5; }
  fi
  if [[ -e $PROFILE_KEY ]]; then
    IFS= read -r header < "$PROFILE_KEY" && [[ $header == '-----BEGIN '*PRIVATE\ KEY----- ]] || {
      log_error 'Invalid private key'; return 1
    }
    fingerprint=$(ssh_fingerprint "$PROFILE_KEY") || { log_error 'Cannot fingerprint private key'; return 1; }
    if [[ -e $PROFILE_KEY.pub ]]; then
      ssh_public_matches "$PROFILE_KEY.pub" "$fingerprint" || { log_error 'SSH key pair mismatch'; return 1; }
    else need=10; fi
    mode=$(ssh_mode "$PROFILE_KEY") || return 1
    case "$mode" in 400|600) ;; *) need=10 ;; esac
  else
    [[ ! -e $PROFILE_KEY.pub ]] || { log_error 'Public key exists without private key'; return 1; }
    [[ ${github_unencrypted:-false} == true || -t 0 ]] || { log_warn 'Key creation requires a terminal or --no-passphrase'; return 4; }
    need=10
  fi
  if [[ -d $HOME/.ssh ]]; then
    mode=$(ssh_mode "$HOME/.ssh") || return 1
    [[ $mode == 700 ]] || need=10
  fi
  return "$need"
}

ssh_local_status() {
  local hosts desired include
  ssh_inspect
}

# The staged inode stays available until verification so a failed two-file
# update can restore the exact originals without removing a replacement.
ssh_publish_file() {
  local name=$1
  [[ -f $stage/new-$name ]] || return 0
  if [[ -f $stage/old-$name ]]; then
    cmp -s "$stage/old-$name" "$name" &&
      ln "$stage/new-$name" "$stage/next" && mv -f "$stage/next" "$name"
  else
    ln "$stage/new-$name" "$name"
  fi
}

ssh_restore_file() {
  local name=$1
  [[ "$stage/new-$name" -ef "$name" ]] || return 0
  if [[ -f $stage/old-$name ]]; then mv -f "$stage/old-$name" "$name"
  else rm -f "$name"; fi
}

ssh_setup() (
  local hosts desired include rc=0 dir="$HOME/.ssh" stage fingerprint mode
  ssh_inspect || rc=$?
  [[ $rc == 10 ]] || return "$rc"
  umask 077
  mkdir -p "$dir" && cd -P -- "$dir" || return 1
  mkdir .dev-bootstrap.lock || { log_error 'Another SSH setup holds the lock'; return 1; }
  stage=.dev-bootstrap.lock
  trap 'rm -rf -- "$stage"' EXIT
  rc=0
  ssh_inspect || rc=$?
  [[ $rc == 10 ]] || return "$rc"
  if [[ $include == orb-missing ]]; then
    [[ -w config ]] && cp -p config "$stage/old-config" &&
      cp -p "$stage/old-config" "$stage/new-config" || return 1
    # Preserve every original byte, including an unterminated final line.
    if [[ -n $(tail -c 1 "$stage/old-config") ]]; then
      printf '\n' >> "$stage/new-config" || return 1
    fi
    printf 'Include ~/.ssh/dev-bootstrap.conf\n' >> "$stage/new-config" || return 1
  elif [[ $include == missing ]]; then
    printf 'Include ~/.ssh/dev-bootstrap.conf\n' > "$stage/new-config" || return 1
    if [[ -f config ]]; then
      [[ -w config ]] || return 1
      cp -p config "$stage/old-config" && cat "$stage/old-config" >> "$stage/new-config" || return 1
      mode=$(ssh_mode config) && chmod "$mode" "$stage/new-config" || return 1
    fi
  fi
  if [[ $hosts != "$desired" ]]; then
    if [[ -f dev-bootstrap.conf ]]; then
      [[ -w dev-bootstrap.conf ]] && cp -p dev-bootstrap.conf "$stage/old-dev-bootstrap.conf" || return 1
    fi
    ssh_render_hosts $desired > "$stage/new-dev-bootstrap.conf" || return 1
  fi
  mode=$(ssh_mode .) || return 1
  [[ $mode == 700 ]] || chmod 700 . || return 1
  if [[ ! -e $PROFILE_KEY ]]; then
    local -a args=(-q -t ed25519 -f "$stage/key" -C "$PROFILE_EMAIL")
    if [[ ${github_unencrypted:-false} == true ]]; then args+=(-N ''); fi
    ssh-keygen "${args[@]}" || return 1
    fingerprint=$(ssh_fingerprint "$stage/key") && ssh_public_matches "$stage/key.pub" "$fingerprint" || return 1
    chmod 600 "$stage/key" && chmod 644 "$stage/key.pub" || return 1
    ln "$stage/key" "$PROFILE_KEY" && ln "$stage/key.pub" "$PROFILE_KEY.pub" || return 1
  elif [[ ! -e $PROFILE_KEY.pub ]]; then
    if [[ -t 0 ]]; then
      ssh-keygen -y -f "$PROFILE_KEY" > "$stage/public" || return 1
    else
      ssh-keygen -y -P '' -f "$PROFILE_KEY" > "$stage/public" 2>/dev/null || {
        log_warn 'Recovering the public key may require an interactive passphrase'; return 4
      }
    fi
    fingerprint=$(ssh_fingerprint "$PROFILE_KEY") && ssh_public_matches "$stage/public" "$fingerprint" || return 1
    chmod 644 "$stage/public" && ln "$stage/public" "$PROFILE_KEY.pub" || return 1
  fi
  mode=$(ssh_mode "$PROFILE_KEY") || return 1
  case "$mode" in 400|600) ;; *) chmod 600 "$PROFILE_KEY" || return 1 ;; esac
  ssh_safe_paths && [[ . -ef "$dir" ]] || return 1
  local latest
  latest=$(ssh_managed_hosts) && [[ $latest == "$hosts" ]] || return 1
  latest=$(ssh_include_state "$PROFILE_ALIAS") && [[ $latest == "$include" ]] || return 4
  if ! ssh_publish_file dev-bootstrap.conf || ! ssh_publish_file config; then
    rc=1
  elif [[ $include == orb-* ]]; then
    ssh_orbstack_effective orb-present "$desired" "$desired" && return 0
    rc=$?
  elif ! ssh_effective_host; then
    rc=5
  else
    return 0
  fi
  ssh_restore_file config && ssh_restore_file dev-bootstrap.conf || {
    # Retain recoverable originals if the filesystem also rejects rollback.
    trap - EXIT
    log_error "Could not restore SSH configuration; inspect $dir/$stage"; return 1
  }
  return "$rc"
)

ssh_doctor() {
  local output rc=0 include fingerprint
  require_command ssh && require_command ssh-keygen || return 3
  ssh_safe_paths || return 1
  [[ -f $PROFILE_KEY && -f $PROFILE_KEY.pub ]] || return 4
  fingerprint=$(ssh_fingerprint "$PROFILE_KEY") && ssh_public_matches "$PROFILE_KEY.pub" "$fingerprint" || {
    log_warn 'Cannot validate the local SSH key pair'; return 4
  }
  include=$(ssh_include_state) || return 1
  [[ $include != conflict ]] || { log_warn 'Review SSH configuration before authentication'; return 4; }
  if [[ $include == present ]]; then ssh_managed_hosts >/dev/null || return $?; fi
  case "$include" in
    orb-missing) return 4 ;;
    orb-present)
      local configured
      configured=$(ssh_managed_hosts) || return $?
      [[ " $configured " == *" $PROFILE_NAME "* ]] || return 4
      ssh_orbstack_effective "$include" "$configured" "$configured" || return 4 ;;
    *) ssh_effective_host || { log_warn 'SSH alias does not select the expected GitHub identity'; return 4; } ;;
  esac
  # Use only the selected identity; ignore proxy commands, multiplexers and
  # other user-configured side effects. Unknown host keys require manual review.
  output=$(ssh -T -F /dev/null -i "$PROFILE_KEY" -o IdentitiesOnly=yes -o BatchMode=yes \
    -o PreferredAuthentications=publickey -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o AddKeysToAgent=no \
    -o ConnectTimeout=8 git@github.com 2>&1) || rc=$?
  if [[ $rc == 1 && $output == "Hi $PROFILE_USER! You've successfully authenticated, but GitHub does not provide shell access." ]]; then
    log_ok "GitHub authenticated as $PROFILE_USER"; return 0
  fi
  log_warn "GitHub SSH authentication did not confirm $PROFILE_USER (exit $rc)"; return 4
}
