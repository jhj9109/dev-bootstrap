#!/usr/bin/env bash
# Build a runnable fixture from the working tree in a fresh test directory.
set -eu
root=$1
dest=$2
mkdir -p "$dest/config"
cp -R "$root"/{setup.sh,bootstrap.sh,core,lib,modules} "$dest/"
# Only ship the project's shared configuration into the fixture.
cp -R "$root/config"/{defaults.conf,environments,*.conf.example} "$dest/config/"
